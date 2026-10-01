//
//  SHVirtualBackend.h
//  Shuttle
//
//  virtual 模式：用原生 screen 后台运行（research R6），不弹终端，替代 virtual-with-screen.scpt。
//

#import <Foundation/Foundation.h>
#import "SHTerminalBackend.h"

NS_ASSUME_NONNULL_BEGIN

@interface SHVirtualBackend : NSObject <SHTerminalBackend>
@end

NS_ASSUME_NONNULL_END