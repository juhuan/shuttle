//
//  SHShuttleConfig.m
//  Shuttle
//

#import "SHShuttleConfig.h"

@implementation SHShuttleConfig

+ (instancetype)configWithJSON:(NSDictionary *)json {
    SHShuttleConfig *config = [[SHShuttleConfig alloc] init];

    config.terminal = [json[@"terminal"] lowercaseString];
    config.editor = [json[@"editor"] lowercaseString];
    config.iTermVersion = [json[@"iTerm_version"] lowercaseString];
    config.openIn = [json[@"open_in"] lowercaseString];
    config.defaultTheme = json[@"default_theme"];
    config.launchAtLogin = [json[@"launch_at_login"] boolValue];

    config.hosts = ([json[@"hosts"] isKindOfClass:[NSArray class]])
        ? [json[@"hosts"] mutableCopy]
        : [NSMutableArray array];

    config.ignoreHosts = ([json[@"ssh_config_ignore_hosts"] isKindOfClass:[NSArray class]])
        ? json[@"ssh_config_ignore_hosts"] : @[];
    config.ignoreKeywords = ([json[@"ssh_config_ignore_keywords"] isKindOfClass:[NSArray class]])
        ? json[@"ssh_config_ignore_keywords"] : @[];

    // show_ssh_config_hosts 缺省视为启用，仅显式 false 关闭。
    BOOL show = YES;
    if ([[json allKeys] containsObject:@"show_ssh_config_hosts"] &&
        [json[@"show_ssh_config_hosts"] boolValue] == NO) {
        show = NO;
    }
    config.showSshConfigHosts = show;

    return config;
}

- (SHTerminalType)terminalType {
    return SHTerminalTypeFromPref(self.terminal);
}

@end