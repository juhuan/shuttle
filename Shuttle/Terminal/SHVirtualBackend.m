//
//  SHVirtualBackend.m
//  Shuttle
//

#import "SHVirtualBackend.h"

@implementation SHVirtualBackend

- (BOOL)dispatchCommand:(SHTerminalCommand *)command error:(NSError **)error {
    NSString *title = command.title ?: @"";

    // 复刻旧 virtual-with-screen.scpt（本质是 do shell script "screen -d -m -S '<title>' <cmd>"）。
    NSString *screenCommand = [NSString stringWithFormat:@"screen -d -m -S '%@' %@", title, command.command];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/sh";
    task.arguments = @[ @"-c", screenCommand ];
    [task launch];
    return YES;
}

@end