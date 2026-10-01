//
//  SHSSHConfigParser.h
//  Shuttle
//
//  ~/.ssh/config 与 /etc/ssh* 解析，按 contracts/ssh-config-parsing.md 复刻旧
//  parseSSHConfigFile / parseSSHConfig 的既有行为（Host 别名、Include 递归、shuttle.* 注释元数据）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SHSSHConfigParser : NSObject

@property (nonatomic, strong) NSFileManager *fileManager; // 可注入（单测用）

/// 按文件来源优先级选择并解析：/etc/ssh_config 优先，~/.ssh/config 存在则覆盖；皆无则返回 nil。
- (nullable NSDictionary<NSString *, NSDictionary *> *)parseConfigFiles;

/// 解析单个 SSH config 文件（含 Include 递归、循环保护）。
- (NSDictionary<NSString *, NSDictionary *> *)parseConfigFile:(NSString *)filepath;

@end

NS_ASSUME_NONNULL_END