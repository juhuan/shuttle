//
//  SHTerminalAppBackend.h
//  Shuttle
//
//  Terminal.app：保留 AppleScript 驱动（research R5）。封装 AppleScript 调用，迁移自旧 AppDelegate 的 runScript:。
//

#import <Foundation/Foundation.h>
#import "SHTerminalBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SHTerminalAppBackend : NSObject <SHTerminalBackend>
@end

NS_ASSUME_NONNULL_END