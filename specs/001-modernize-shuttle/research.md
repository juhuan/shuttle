# Research: Shuttle 现代化大重构技术决策

本文件记录 Phase 0 研究产出的关键技术决策、理由与备选方案，逐个消除 plan.md Technical Context 中的 NEEDS CLARIFICATION。决策顺序对应风险从高到低。

## R1. 最低部署目标 → macOS 13 (Ventura)

- **Decision**: `MACOSX_DEPLOYMENT_TARGET = 13.0`（`LSMinimumSystemVersion` 随之联动）。
- **Rationale**: FR-002 要求开机自启用 `SMAppService`，该 API 自 macOS 13 引入；规格已拍板最低目标为 Ventura，无需降级路径。现有代码注释已写明"requires 10.15+"，13.0 是自然升级。
- **Alternatives considered**:
  - 保留 10.15 + SMAppService 条件编译降级到 `SMLoginItemSetEnabled` —— 被否（增加双路径复杂度，且 `SMLoginItemSetEnabled` 亦已废弃）。
  - 用打包 LaunchAgent helper —— 被否（需引入第二个可执行文件与额外加载路径）。

## R2. 开机自启 → `SMAppService.mainApp`

- **Decision**: 删除 `LaunchAtLoginController`（`LSSharedFileList` 实现，10.10 起废弃），新增 `SHLaunchAtLogin` 封装 `[SMAppService mainApp]` 的 `status` / `registerAndReturnError:` / `unregisterAndReturnError:`。
- **Rationale**: 受支持 API；登录项状态与「系统设置 → 通用 → 登录项」天然同步，直接满足 Edge Case「自启状态与系统真实状态保持一致」（FR-002）。
- **Alternatives considered**:
  - `SMLoginItemSetEnabled` —— 已废弃。
  - 手动写入 `~/Library/Application Support/com.apple.backgroundtaskmanagementagent` —— 私有权术，不稳定，被否。

## R3. iTerm2 驱动 → `iterm2://` URL scheme

- **Decision**: iTerm2 后端改为通过其命令 URL scheme 派发，核心形态为 `iterm2:/command?c=<command>`（可选 `d=<dir>` 切换目录、`silent` 抑制交互窗）。
- **Rationale**: iTerm2 官方文档明确定义了以 `iterm2` 为 scheme、`/command` 为 path 的命令 URL（见 [Command URLs](https://iterm2.com/documentation-command-selection.html) 与 [URL Scheme](https://iterm2.com/documentation-url-scheme.html)）。借此可**移除 iTerm2 的 AppleScript 与 Apple Events 自动化授权**。
- **Caveats (需实现阶段验证)**:
  - 原生命令 URL 默认弹「如何运行」选项窗；`inTerminal` 的 `tab`/`new`/`current` 三种模式如何精确映射需对照完整的 URL Scheme 文档确认参数（实现阶段务必读全，勿只依赖命令 URL 一页）。
  - `iterm_version`（stable/nightly）字段仍需被解析（保持 JSON 兼容），但 URL scheme 通常由系统按已安装 iTerm2 路由，stable/nightly 差异可能不再影响派发。
- **Alternatives considered**:
  - 保留 AppleScript（现状）—— 被否，13 个脚本维护成本高。
  - iTerm2 Python API —— 需安装 Python 运行时，破坏"单一二进制"约束，被否。

## R4. Ghostty 驱动 → 自身 CLI

- **Decision**: Ghostty 后端改为调用其 CLI：`ghostty +new-window -e <cmd>`、`+new-tab -e <cmd>`、`+new-split -e <cmd>`，可附 `--working-directory=`。二进制路径回退 `ghostty`（若在 PATH）或 `/Applications/Ghostty.app/Contents/MacOS/ghostty`。
- **Rationale**: Ghostty 官方 CLI 支持上述 `+action` IPC 命令及 `-e` 启动命令（见 [Ghostty AppleScript/CLI 文档](https://ghostty.org/docs/features/applescript) 及 `+list-actions`）。移除了 Ghostty 的 AppleScript 与配套 Apple Events 授权。
- **Caveats**:
  - `inTerminal: current`（在已存在的当前终端运行）CLI 无直接等价动作，实现阶段需定义明确的降级语义（例如映射为 `+new-tab` 并给出可读提示，或视 Ghostty 版本用 `+enter`），并记入 quickstart 的验证边界。
- **Alternatives considered**:
  - 保留 AppleScript（Ghostty 1.3.0 已引入 AppleScript 字典）—— 被否：与"收敛 AppleScript、减少维护面"的既定方向相悖。
  - `do shell script` 拼 AppleScript —— 被否，同上。

## R5. Terminal.app 驱动 → 保留 AppleScript

- **Decision**: Terminal.app 是唯一三端中无等价 URL scheme/CLI 派发通道、仍需 AppleScript 的终端，保留 3 个脚本 `terminal-new-window/current-window/new-tab-default`，其余 10 个脚本删除。
- **Rationale**: `tell application "Terminal"` + `do script` 是驱动 Terminal.app 的最简可靠途径。精简后仅需在 entitlements 保留 `com.apple.terminal` 的 Apple Events 授权。
- **Alternatives considered**: 无（Terminal.app 无命令行/URL 派发通道）。

## R6. virtual 模式 → 原生 `screen`

- **Decision**: `virtual-with-screen.scpt`（本质是 `do shell script "screen -d -m -S '<title>' <cmd>"`）改为 `SHVirtualBackend` 用 `NSTask` 直接执行 `screen -d -m -S <title> <cmd>`，删除该脚本。
- **Rationale**: 与终端无关，本就只是 shell 调用，无需 AppleScript；`screen` 为系统自带。
- **Alternatives considered**: 用 `NSTask`+`nohup`/`setsid` —— 被否，`screen` 语义（可重连会话、带标题）与既有 `virtual` 行为一致，保持无回归。

## R7. `¬_¬` 定界字符串传参 → 轻量模型对象

- **Decision**: 用 `SHTerminalCommand`（command/theme/title/openMode/terminalType/fallbackName）+ `SHMenuNode`（菜单树）模型对象替换 `representedObject` 里 `cmd¬_¬theme¬_¬title¬_¬window¬_¬name` 的字符串拼接与拆分。
- **Rationale**: 字符串定界脆弱（值内含定界符即错乱），且类型不透明。模型对象可被单测直接断言（支撑 SC-004/SC-005）。
- **Alternatives considered**: `NSDictionary` 传参 —— 比字符串略好但仍无类型安全，被否。

## R8. 上帝对象拆分

- **Decision**: 按 plan.md 的 `Config`/`Menu`/`Terminal` 分组拆分 `AppDelegate`，职责单一；`AppDelegate` 仅保留应用生命周期、状态栏项、menu delegate 与热更新触发。
- **Rationale**: 满足 FR-007（拆分为单一职责模块）与 FR-012（纯逻辑可单测）。纯逻辑（解析、构建、命令生成）不依赖 UI，可 headless 测试。
- **Alternatives considered**: 激进引入 Swift 重写 —— 被否（超出"重构"范畴，破坏兼容风险更大，且规格明确沿用 Objective-C）。

## R9. 统一 ARC

- **Decision**: 移除 `LaunchAtLoginController.m` 的 `-fno-objc-arc` 编译开关（该文件被重写后随删除自然实现）；全 target `CLANG_ENABLE_OBJC_ARC = YES`。
- **Rationale**: 消除手动 `retain/release` 与非 ARC 编译例外（FR-009）。经查证该项目仅此一个文件非 ARC。
- **Alternatives considered**: 无。

## R10. 测试策略 → XCTest 单元 target

- **Decision**: 新增 `ShuttleTests`（XCTest）target，测试纯逻辑：`SHSSHConfigParser`、`SHMenuBuilder`、`SHConfigSource`、`SHShuttleConfig`。菜单构建测试通过"构建数据树"而非 NSMenu 断言（或利用 macOS headless 直接断言 NSMenu 结构），使其可在无 GUI CI 下跑。
- **Rationale**: FR-012 / SC-005。终端实际控制与 AppleScript 执行属集成/手动测试，不进单测。
- **Alternatives considered**: 保留 Python 脚本方案 —— 覆盖不足、与 ObjC 类型脱节，仅作参考保留。

## R11. 工程与签名公证

- **Decision**:
  - `MACOSX_DEPLOYMENT_TARGET` 13.0；`LastUpgradeCheck` 更新；`CODE_SIGN_IDENTITY` 释放时由 CI 注入 Developer ID，本地构建留 ad-hoc（`-`）。
  - CI（`.github/workflows/`）升级为：单测 → `xcodebuild -scheme Shuttle build`（Release，签名）→ `xcrun notarytool submit` → `stapler staple` → `hdiutil` 打 DMG。
  - 新增共享 scheme（当前工程无显式 scheme，CI 靠默认 target 推断，需补齐）。
- **Rationale**: FR-013 / FR-014 / SC-006 / SC-007；消除 Gatekeeper 拦截（SC-001）。
- **Caveats**: 签名/公证依赖 Apple Developer 证书与公证凭据（由仓库所有者提供，写入 CI Secrets），见 Assumptions。
- **Alternatives considered**: 沿用未签名 DMG —— 被否，现代 macOS 下被拦截即违背核心目标。

## R12. entitlements 收敛

- **Decision**: 收窄 `Shuttle.entitlements` 的 Apple Events 授权，仅保留 `com.apple.terminal`。现有 `com.googlecode.iterm2` 与 `com.mitchellh.ghostty` 不再需要（iTerm2 走 URL scheme、Ghostty 走 CLI，均不经 Apple Events）。
- **Rationale**: 最小权限原则；也顺带修正了历史遗留——当前 entitlements **已包含** `com.mitchellh.ghostty`（见 [Shuttle.entitlements](../../Shuttle/Shuttle.entitlements)），FR-004 的"声明 Ghostty 授权"在方向上转为"因改用 CLI 而可移除"。
- **Alternatives considered**: 保留全部三项授权 —— 无害但非最小权限，被否。

## 已消除的 NEEDS CLARIFICATION 汇总

| 未知项 | 结论 |
|---|---|
| 最低部署目标 | macOS 13.0（R1） |
| 自启实现 | SMAppService.mainApp（R2） |
| iTerm2 派发 | iterm2:// URL scheme（R3） |
| Ghostty 派发 | 自身 CLI（R4） |
| Terminal.app 派发 | 保留 AppleScript（R5） |
| virtual 模式 | 原生 screen（R6） |
| 测试框架 | XCTest（R10） |

## 待实现阶段验证的开放项（不影响本计划结构）

1. iTerm2 URL scheme 对 `tab/new/current` 三模式的精确参数映射（R3 Caveats）。
2. Ghostty `inTerminal: current` 的降级语义（R4 Caveats）。
3. CI 签名/公证所需 Secrets 的命名与注入约定（R11）。