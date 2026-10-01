//
//  SHTerminalCommand.h
//  Shuttle
//
//  终端命令值对象：替换原先用 "¬_¬" 定界字符串在菜单项间传参的脆弱做法。
//  保存待派发命令的原始字段，派发前通过 resolve 方法做归一化（复刻旧 openHost 的
//  theme -> title -> openMode 判定顺序），结果写回自身。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 打开方式。
typedef NS_ENUM(NSInteger, SHOpenMode) {
    SHOpenModeInvalid = -1,
    SHOpenModeTab     = 0,  // 新 tab（默认）
    SHOpenModeNew     = 1,  // 新窗口
    SHOpenModeCurrent = 2,  // 当前窗口
    SHOpenModeVirtual = 3,  // 后台 screen 运行，不弹终端
};

/// 终端类型（决定派发后端）。
typedef NS_ENUM(NSInteger, SHTerminalType) {
    SHTerminalTypeTerminal = 0,  // Terminal.app（保留 AppleScript）
    SHTerminalTypeITerm    = 1,  // iTerm2（iterm2:// URL scheme）
    SHTerminalTypeGhostty  = 2,  // Ghostty（自身 CLI）
};

/// 按子串匹配终端类型：ghostty -> Ghostty，iterm -> iTerm，其余 -> Terminal.app（复刻旧 openHost）。
FOUNDATION_EXPORT SHTerminalType SHTerminalTypeFromPref(NSString * _Nullable terminalPref);

@interface SHTerminalCommand : NSObject

@property (nonatomic, copy) NSString *command;                  // 待执行命令（必需）
@property (nonatomic, copy, nullable) NSString *theme;          // 会话主题（原始，可为空）
@property (nonatomic, copy, nullable) NSString *title;          // 窗口/标签标题（原始，可为空）
@property (nonatomic, copy, nullable) NSString *inTerminal;     // 原始打开方式：tab/new/current/virtual（可为空）
@property (nonatomic, assign) SHOpenMode openMode;              // 归一化后的打开方式（resolve 之后有效）
@property (nonatomic, copy, nullable) NSString *fallbackName;   // 去除排序/分隔符标记后的菜单显示名，title 为空时回退
@property (nonatomic, assign) SHTerminalType terminalType;

/// 归一化 theme / title / openMode，结果写回 self 的 theme/title/openMode。严格复刻旧 openHost 判定顺序：
///   1. theme 为空且无全局 default_theme -> iTerm 用 "Default"、其余用 "basic"；有全局主题则用之。
///   2. title 为空 -> 回退 fallbackName。
///   3. inTerminal 为空 -> 用全局 open_in（仅允许 tab/new，否则强制 tab）；非空则校验四类取值，非法返回 NO 并填 error。
- (BOOL)resolveWithGlobalTheme:(nullable NSString *)globalTheme
                  globalOpenIn:(nullable NSString *)globalOpenIn
                         error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END