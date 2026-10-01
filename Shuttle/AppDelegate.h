//
//  AppDelegate.h
//  Shuttle
//

#import <Cocoa/Cocoa.h>

@class SHConfigSource;
@class SHShuttleConfig;
@class SHSSHConfigParser;
@class SHLaunchAtLogin;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate> {
    IBOutlet NSMenu *menu;
    IBOutlet NSArrayController *arrayController;

    NSImage *regularIcon;
    NSImage *altIcon;
    NSStatusItem *statusItem;

    SHConfigSource *configSource;
    SHShuttleConfig *config;
    SHSSHConfigParser *sshParser;
    SHLaunchAtLogin *launchAtLogin;
}

- (void)menuWillOpen:(NSMenu *)menu;

@end