//
//  SHGhosttyBackend.h
//  Shuttle
//
//  Ghostty：改用自身 CLI 派发（research R4），移除 AppleScript 与 Apple Events 授权。
//

#import <Foundation/Foundation.h>
#import "SHTerminalBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SHGhosttyBackend : NSObject <SHTerminalBackend>
@end

NS_ASSUME_NONNULL_END