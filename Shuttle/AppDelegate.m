//
//  AppDelegate.m
//  Shuttle
//

#import "AppDelegate.h"
#import "AboutWindowController.h"

#import "SHConfigSource.h"
#import "SHShuttleConfig.h"
#import "SHSSHConfigParser.h"
#import "SHMenuBuilder.h"
#import "SHMenuNode.h"
#import "SHTerminalCommand.h"
#import "SHTerminalBackend.h"
#import "SHTerminalAppBackend.h"
#import "SHITermBackend.h"
#import "SHGhosttyBackend.h"
#import "SHVirtualBackend.h"
#import "SHLaunchAtLogin.h"

@implementation AppDelegate

- (void)awakeFromNib {
    configSource = [[SHConfigSource alloc] init];
    sshParser = [[SHSSHConfigParser alloc] init];
    launchAtLogin = [[SHLaunchAtLogin alloc] init];

    regularIcon = [NSImage imageNamed:@"StatusIcon"];
    altIcon = [NSImage imageNamed:@"StatusIconAlt"];

    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusItem setMenu:menu];
    statusItem.button.image = regularIcon;
    regularIcon.template = YES;

    [menu setDelegate:self];
}

- (void)menuWillOpen:(NSMenu *)aMenu {
    if ([configSource needsMenuReload]) {
        [self loadMenu];
    }
}

- (void)loadMenu {
    // 清空动态项，保留尾部固定项（退出/关于等）。
    NSInteger n = [[menu itemArray] count];
    for (NSInteger i = 0; i < n - 4; i++) {
        [menu removeItemAtIndex:0];
    }

    NSData *data = [NSData dataWithContentsOfFile:configSource.jsonPath];
    id json = [NSJSONSerialization JSONObjectWithData:data
                                              options:NSJSONReadingMutableContainers
                                                error:nil];
    if (!json) {
        NSMenuItem *menuItem = [menu insertItemWithTitle:NSLocalizedString(@"Error parsing config", nil)
                                                  action:false
                                           keyEquivalent:@""
                                                 atIndex:0];
        [menuItem setEnabled:false];
        return;
    }

    config = [SHShuttleConfig configWithJSON:json];

    launchAtLogin.launchAtLogin = config.launchAtLogin;

    NSMutableArray *hosts = config.hosts;

    // 合并第二配置的 hosts。
    if (configSource.parseAltJSON) {
        NSData *dataAlt = [NSData dataWithContentsOfFile:configSource.altJsonPath];
        id jsonAlt = [NSJSONSerialization JSONObjectWithData:dataAlt
                                                     options:NSJSONReadingMutableContainers
                                                       error:nil];
        NSArray *hostsAlt = jsonAlt[@"hosts"];
        if ([hostsAlt isKindOfClass:[NSArray class]]) {
            [hosts addObjectsFromArray:hostsAlt];
        }
    }

    // SSH 主机注入。
    SHMenuBuilder *builder = [[SHMenuBuilder alloc] init];
    if (config.showSshConfigHosts) {
        NSDictionary *servers = [sshParser parseConfigFiles];
        if (servers != nil) {
            hosts = [builder injectSSHHosts:servers
                                   intoHosts:hosts
                                 ignoreHosts:config.ignoreHosts
                              ignoreKeywords:config.ignoreKeywords];
        }
    }

    NSArray<SHMenuNode *> *tree = [builder buildTreeFromHosts:hosts terminalType:config.terminalType];
    [self addMenuNodes:tree toMenu:menu atIndex:0];
}

- (void)addMenuNodes:(NSArray<SHMenuNode *> *)nodes toMenu:(NSMenu *)m atIndex:(NSInteger)start {
    NSInteger pos = start;
    for (SHMenuNode *node in nodes) {
        if (node.isLeaf) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:node.title
                                                          action:@selector(openHost:)
                                                   keyEquivalent:@""];
            [item setTarget:self];
            [item setRepresentedObject:node.command];
            [m insertItem:item atIndex:pos++];
            if (node.appendSeparator) {
                [m insertItem:[NSMenuItem separatorItem] atIndex:pos++];
            }
        } else {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:node.title
                                                          action:NULL
                                                   keyEquivalent:@""];
            NSMenu *subMenu = [[NSMenu alloc] init];
            [item setSubmenu:subMenu];
            [m insertItem:item atIndex:pos++];
            if (node.appendSeparator) {
                [m insertItem:[NSMenuItem separatorItem] atIndex:pos++];
            }
            [self addMenuNodes:node.children toMenu:subMenu atIndex:0];
        }
    }
}

- (void)openHost:(NSMenuItem *)sender {
    SHTerminalCommand *command = [sender representedObject];
    if (![command isKindOfClass:[SHTerminalCommand class]]) {
        return;
    }
    [self dispatchCommand:command];
}

- (void)dispatchCommand:(SHTerminalCommand *)command {
    NSError *resolveError = nil;
    if (![command resolveWithGlobalTheme:config.defaultTheme
                            globalOpenIn:config.openIn
                                   error:&resolveError]) {
        NSString *info = NSLocalizedString(@"bad \"inTerminal\":\"VALUE\" in the JSON settings", nil);
        [self throwError:resolveError.localizedDescription additionalInfo:info continueOnErrorOption:NO];
        return;
    }

    // URL 快捷方式：非 virtual 且为合法 URL 时直接用系统默认应用打开（复刻旧 openHost）。
    if (command.openMode != SHOpenModeVirtual && [self isValidURL:command.command]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:command.command]];
        return;
    }

    id<SHTerminalBackend> backend = [self backendForCommand:command];
    NSError *dispatchError = nil;
    [backend dispatchCommand:command error:&dispatchError];
}

- (id<SHTerminalBackend>)backendForCommand:(SHTerminalCommand *)command {
    if (command.openMode == SHOpenModeVirtual) {
        return [[SHVirtualBackend alloc] init];
    }
    switch (command.terminalType) {
        case SHTerminalTypeGhostty:
            return [[SHGhosttyBackend alloc] init];
        case SHTerminalTypeITerm:
            return [[SHITermBackend alloc] init];
        case SHTerminalTypeTerminal:
        default:
            return [[SHTerminalAppBackend alloc] init];
    }
}

- (IBAction)showImportPanel:(id)sender {
    NSOpenPanel *openPanelObj = [NSOpenPanel openPanel];
    NSInteger tvarNSInteger = [openPanelObj runModal];
    if (tvarNSInteger == NSModalResponseOK) {
        // 备份当前配置
        [[NSFileManager defaultManager] moveItemAtPath:configSource.jsonPath
                                                toPath:[NSHomeDirectory() stringByAppendingPathComponent:@".shuttle.json.backup"]
                                                 error:nil];
        NSURL *selectedFileUrl = [openPanelObj URL];
        [[NSFileManager defaultManager] copyItemAtPath:selectedFileUrl.path toPath:configSource.jsonPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@".shuttle.json.backup"]
                                                   error:nil];
    }
}

- (BOOL)isValidURL:(NSString *)string {
    NSURL *url = [NSURL URLWithString:string];
    if (!url) return NO;

    NSString *scheme = [url scheme];
    if (!scheme) return NO;

    NSArray *validSchemes = @[@"http", @"https", @"ftp", @"file", @"ssh", @"telnet"];
    return [validSchemes containsObject:scheme.lowercaseString];
}

- (void)throwError:(NSString *)errorMessage additionalInfo:(NSString *)errorInfo continueOnErrorOption:(BOOL)continueOption {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:errorInfo];
    [alert setMessageText:errorMessage];
    [alert setAlertStyle:NSAlertStyleWarning];

    if (continueOption) {
        [alert addButtonWithTitle:NSLocalizedString(@"Quit", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Continue", nil)];
    } else {
        [alert addButtonWithTitle:NSLocalizedString(@"Quit", nil)];
    }

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [NSApp terminate:NSApp];
    }
}

- (IBAction)showExportPanel:(id)sender {
    NSSavePanel *savePanelObj = [NSSavePanel savePanel];
    NSInteger result = [savePanelObj runModal];
    if (result == NSModalResponseOK) {
        NSURL *saveURL = [savePanelObj URL];
        [[NSFileManager defaultManager] copyItemAtPath:configSource.jsonPath toPath:saveURL.path error:nil];
    }
}

- (IBAction)configure:(id)sender {
    if ([config.editor rangeOfString:@"default"].location != NSNotFound) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:configSource.jsonPath]];
    } else {
        NSString *editorCommand = [NSString stringWithFormat:@"%@ %@", config.editor, configSource.jsonPath];

        SHTerminalCommand *command = [[SHTerminalCommand alloc] init];
        command.command = editorCommand;
        command.title = @"Editing shuttle JSON";
        command.terminalType = config.terminalType;

        [self dispatchCommand:command];
    }
}

- (IBAction)showAbout:(id)sender {
    AboutWindowController *aboutWindow = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindowController"];
    [aboutWindow.window makeKeyAndOrderFront:nil];
    [aboutWindow.window setLevel:NSFloatingWindowLevel];
    [aboutWindow showWindow:self];
}

- (IBAction)quit:(id)sender {
    [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
    [NSApp terminate:NSApp];
}

@end