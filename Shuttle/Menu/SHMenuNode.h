//
//  SHMenuNode.h
//  Shuttle
//
//  菜单树节点：替换原先「直接建 NSMenu + ¬_¬ 字符串传参」的构建方式，使菜单结构可被单元测试断言。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SHTerminalCommand;

@interface SHMenuNode : NSObject

@property (nonatomic, copy) NSString *title;                 // 去除 [aaa]/[---] 标记后的显示名
@property (nonatomic, assign, getter=isLeaf) BOOL leaf;       // YES=叶子(命令)，NO=目录
@property (nonatomic, strong, nullable) SHTerminalCommand *command;   // 叶子：待派发命令
@property (nonatomic, copy, nullable) NSArray<SHMenuNode *> *children; // 目录：子节点（先目录后叶子）
@property (nonatomic, assign) BOOL appendSeparator;           // 该项之后追加分隔符

@end

NS_ASSUME_NONNULL_END