//
//  SHITermBackend.m
//  Shuttle
//

#import "SHITermBackend.h"

@implementation SHITermBackend

- (BOOL)dispatchCommand:(SHTerminalCommand *)command error:(NSError **)error {
    // 构造 iterm2:/command?c=<command>（research R3）。
    // 已知边界：tab/new/current 的精细映射由 iTerm2 原生「如何运行」提示窗决定（见 quickstart 已知边界）。
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"iterm2";
    components.path = @"/command";
    components.queryItems = @[ [NSURLQueryItem queryItemWithName:@"c" value:command.command] ];

    NSURL *url = components.URL;
    if (url == nil) {
        return NO;
    }
    [[NSWorkspace sharedWorkspace] openURL:url];
    return YES;
}

@end