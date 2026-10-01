//
//  SHMenuBuilder.h
//  Shuttle
//
//  把 hosts 数组构建为 SHMenuNode 树，并负责 ~/.ssh/config 主机注入。
//  复刻旧 buildMenu / separatorSortRemoval / loadMenu（SSH 注入）逻辑，供无 GUI 单测断言。
//

#import <Foundation/Foundation.h>
#import "SHMenuNode.h"
#import "SHTerminalCommand.h"

NS_ASSUME_NONNULL_BEGIN

@interface SHMenuBuilder : NSObject

/// 复刻旧 loadMenu 的 SSH 主机注入：把 servers 按忽略规则/路径细分合并进 hosts（原地修改可变结构）。
- (NSMutableArray *)injectSSHHosts:(NSDictionary<NSString *, NSDictionary *> *)servers
                          intoHosts:(NSMutableArray *)hosts
                        ignoreHosts:(NSArray *)ignoreHosts
                     ignoreKeywords:(NSArray *)ignoreKeywords;

/// 复刻旧 buildMenu + separatorSortRemoval：目录/叶子按原始名 localizedCaseInsensitiveCompare 排序，
/// 先目录后叶子；[aaa]/[---] 标记去除；叶子生成 SHTerminalCommand。
- (NSArray<SHMenuNode *> *)buildTreeFromHosts:(NSArray *)hosts terminalType:(SHTerminalType)terminalType;

@end

NS_ASSUME_NONNULL_END