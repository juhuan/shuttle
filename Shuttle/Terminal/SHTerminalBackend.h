//
//  SHTerminalBackend.h
//  Shuttle
//
//  终端派发策略协议：对某一种终端（含 virtual 后台模式）如何发起命令/会话。
//  各实现读取已归一化的 SHTerminalCommand（theme/title/openMode 均已解析）。
//

#import <Foundation/Foundation.h>
#import "SHTerminalCommand.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SHTerminalBackend <NSObject>
@required

/// 派发一条已归一化的命令。
- (BOOL)dispatchCommand:(SHTerminalCommand *)command error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END