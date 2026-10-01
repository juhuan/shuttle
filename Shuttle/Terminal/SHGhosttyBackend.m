//
//  SHGhosttyBackend.m
//  Shuttle
//

#import "SHGhosttyBackend.h"

@implementation SHGhosttyBackend

- (BOOL)dispatchCommand:(SHTerminalCommand *)command error:(NSError **)error {
    NSString *action = nil;
    switch (command.openMode) {
        case SHOpenModeNew:     action = @"+new-window"; break;
        case SHOpenModeTab:     action = @"+new-tab"; break;
        // 已知边界（research R4）：current 无 CLI 等价动作，降级为 +new-tab。
        case SHOpenModeCurrent: action = @"+new-tab"; break;
        default:
            return NO;
    }

    NSString *ghostty = [self ghosttyBinaryPath];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = ghostty;
    // 命令在 shell 中运行（等价于旧 AppleScript 的 do script 语义）。
    task.arguments = @[ action, @"-e", @"/bin/zsh", @"-lc", command.command ];
    [task launch];
    return YES;
}

- (NSString *)ghosttyBinaryPath {
    NSString *appPath = @"/Applications/Ghostty.app/Contents/MacOS/ghostty";
    if ([[NSFileManager defaultManager] isExecutableFileAtPath:appPath]) {
        return appPath;
    }
    return @"ghostty"; // 回退依赖 PATH
}

@end