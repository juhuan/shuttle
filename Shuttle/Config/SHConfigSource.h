//
//  SHConfigSource.h
//  Shuttle
//
//  配置/SSH 路径解析（.shuttle.path / .shuttle-alt.path / 默认回退）与 mtime 热更新判定，
//  严格复刻旧 AppDelegate 的 awakeFromNib / needUpdateFor / getMTimeFor / menuWillOpen。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SHConfigSource : NSObject

@property (nonatomic, copy, readonly) NSString *jsonPath;       // 主配置绝对路径
@property (nonatomic, copy, readonly) NSString *altJsonPath;    // 第二配置绝对路径
@property (nonatomic, assign, readonly) BOOL parseAltJSON;      // 是否解析第二配置

// 内部 mtime 状态（menuWillOpen 热更新判定用）。
@property (nonatomic, copy, nullable) NSDate *jsonMTime;
@property (nonatomic, copy, nullable) NSDate *altJsonMTime;
@property (nonatomic, copy, nullable) NSDate *sshSystemMTime;
@property (nonatomic, copy, nullable) NSDate *sshUserMTime;

/// 使用真实 NSHomeDirectory 与默认文件管理器（应用运行时用）。
- (instancetype)init;

/// 注入 home 目录与文件管理器（单测用）。
- (instancetype)initWithHomeDirectory:(NSString *)home fileManager:(NSFileManager *)fileManager;

/// 复刻旧的 getMTimeFor：返回文件修改时间。
- (NSDate *)mtimeForFile:(NSString *)file;

/// 复刻旧的 needUpdateFor：文件不存在 -> NO；无旧时间 -> YES；否则比对 mtime。
- (BOOL)needUpdateForFile:(NSString *)file old:(nullable NSDate *)old;

/// 复刻 menuWillOpen 的四文件判定（json / alt / /etc/ssh/ssh_config / ~/.ssh/config）；命中则刷新内部 mtime 并返回 YES。
- (BOOL)needsMenuReload;

@end

NS_ASSUME_NONNULL_END