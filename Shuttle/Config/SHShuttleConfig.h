//
//  SHShuttleConfig.h
//  Shuttle
//
//  ~/.shuttle.json 根值对象：字段与校验严格遵循 contracts/json-config-schema.md。
//  terminal / editor / iTerm_version / open_in 的值一律 lowercaseString（与现状一致）。
//

#import <Foundation/Foundation.h>
#import "SHTerminalCommand.h"

NS_ASSUME_NONNULL_BEGIN

@interface SHShuttleConfig : NSObject

@property (nonatomic, copy, nullable) NSString *terminal;      // 小写
@property (nonatomic, copy, nullable) NSString *editor;        // 小写，default = 系统默认打开
@property (nonatomic, copy, nullable) NSString *iTermVersion;  // 小写 stable/nightly（兼容保留）
@property (nonatomic, copy, nullable) NSString *openIn;        // 小写 tab/new/current
@property (nonatomic, copy, nullable) NSString *defaultTheme;
@property (nonatomic, assign) BOOL launchAtLogin;
@property (nonatomic, strong) NSMutableArray *hosts;           // 菜单树（可变）
@property (nonatomic, copy) NSArray *ignoreHosts;
@property (nonatomic, copy) NSArray *ignoreKeywords;
@property (nonatomic, assign) BOOL showSshConfigHosts;

/// 由 terminal 字段派生（子串匹配）。
@property (nonatomic, readonly) SHTerminalType terminalType;

/// 从解析后的 JSON 字典构建。
+ (instancetype)configWithJSON:(NSDictionary *)json;

@end

NS_ASSUME_NONNULL_END