# Quickstart：构建、测试与端到端验证

本指南面向 macOS 13+ 的开发者，验证重构后的 Shuttle 端到端可用。前置约定见 [plan.md](./plan.md)、[data-model.md](./data-model.md) 与 [contracts/](./contracts/)。

## 前置条件

- macOS 13 (Ventura) 及以上。
- 当前版本 Xcode（含命令行工具）。
- （仅发版验证）Apple Developer ID Application 证书 + App Store Connect API 公证凭据，写入 CI/本地环境变量（见 R11）。
- 可选安装：Terminal.app（系统自带）、iTerm2、Ghostty，用于三终端验证。

## 构建

```bash
# 本地 Debug 构建（无签名/ad-hoc 签名，便于开发）
xcodebuild -project Shuttle.xcodeproj -scheme Shuttle -configuration Debug build

# Release 构建产物位于 build/Release/Shuttle.app
xcodebuild -project Shuttle.xcodeproj -scheme Shuttle -configuration Release build
```

> 若工程尚未有共享 scheme，先 `xcodebuild -list` 确认；CI 中由 R11 补齐 scheme 生成。

## 运行单元测试

```bash
xcodebuild test -project Shuttle.xcodeproj -scheme Shuttle \
  -destination 'platform=macOS' | xcpretty
```

预期：`SHSSHConfigParserTests`、`SHMenuBuilderTests`、`SHConfigSourceTests`、`SHShuttleConfigTests` 全部通过，且可在无 GUI 的 CI runner 上执行。

## 端到端验证清单

### 1. 安装运行（User Story 1）

1. `open build/Release/Shuttle.app` → 状态栏出现图标，无「无法验证开发者」拦截（Release 已签名+公证时）。
2. 勾选「开机自启」→ 注销/重登 → 应用自动启动；关闭后重登不启动。
3. 在「系统设置 → 通用 → 登录项」中手动移除 Shuttle → 应用能反映真实（未自启）状态。

### 2. 三终端派发（User Story 2）

用以下最小 `~/.shuttle.json`，分别改 `terminal` 字段验证：

```json
{
  "terminal": "Terminal.app",
  "open_in": "tab",
  "hosts": [
    { "name": "测试命令", "cmd": "echo hello-from-shuttle" }
  ]
}
```

| terminal 取值 | 预期 |
|---|---|
| `Terminal.app` | 命令在 Terminal.app 新 tab 运行（首次触发 Apple Events 授权弹窗，授予后再无异常）|
| `iTerm` | 命令经 iTerm2 打开（URL scheme 派发）|
| `Ghostty.app` | 命令在 Ghostty 新窗口/tab 运行（CLI 派发）|

覆盖 `open_in`/`inTerminal` 的 `tab`/`new`/`current`/`virtual` 四种模式；`virtual` 应后台 `screen` 运行不弹终端。

### 3. 无回归比对（User Story 3）

- 用含嵌套菜单、`[aaa]`、`[---]`、`theme`/`title`/`inTerminal` 的样例 JSON，肉眼/快照比对重构前后菜单的名称、层级、顺序、分隔符、命令逐项一致。
- 用含 `Host`/`Include`/注释/通配符/`.hidden` 的 `~/.ssh/config` 比对主机注入结果。
- 用语法错误的 JSON 验证「配置解析错误」提示且不崩溃。

### 4. 测试覆盖（User Story 4）

`xcodebuild test` 后查看覆盖率报告，解析/构建核心逻辑行覆盖 ≥ 70%（SC-005）。

### 5. 发版产物（User Story 5）

```bash
./build.sh   # 或 CI 流水线，产出已签名+公证的 Shuttle.dmg
```

核对 DMG 已 `stapler staple`，可在 macOS 13+ 直接安装运行（SC-001/SC-006）。

## 已知边界（实现阶段需复核）

- iTerm2 URL scheme 对 `tab/new/current` 的精确参数映射（research R3）。若命令行 URL 无法无损表达 `current`，需明确降级语义并记录。
- Ghostty `inTerminal: current` 的降级行为（research R4）。