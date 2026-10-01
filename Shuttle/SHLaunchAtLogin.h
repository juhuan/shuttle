//
//  SHLaunchAtLogin.h
//  Shuttle
//
//  开机自启：用 SMAppService.mainApp（macOS 13+）替换废弃的 LSSharedFileList（research R2）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SHLaunchAtLogin : NSObject

@property (nonatomic, assign) BOOL launchAtLogin;

@end

NS_ASSUME_NONNULL_END