//
//  SHITermBackend.h
//  Shuttle
//
//  iTerm2：改用 iterm2:// URL scheme 派发（research R3），移除 AppleScript 与 Apple Events 授权。
//

#import <Foundation/Foundation.h>
#import "SHTerminalBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SHITermBackend : NSObject <SHTerminalBackend>
@end

NS_ASSUME_NONNULL_END