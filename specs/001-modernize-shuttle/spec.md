# Feature Specification: Shuttle 现代化大重构

**Feature Branch**: `001-modernize-shuttle`

**Created**: 2026-10-01

**Status**: Draft

**Input**: 用户描述：对 Shuttle（macOS 菜单栏 SSH/终端快捷菜单应用，Objective-C + Cocoa/AppKit + AppleScript + JSON 配置，2013 年起未实质更新的老项目）做一次完整且大的重构：修复失效的底层 API、拆分上帝对象、统一 ARC、收敛 AppleScript、补单测、升级工程与发版，目标是让应用在现代 macOS（13+）上能正常构建、安装、运行，且代码可维护可测试。

## 背景与目标

Shuttle 是一个历史长达十余年的 macOS 状态栏应用，核心功能（读 JSON/SSH 配置、构建菜单、通过 AppleScript 驱动终端）仍然有价值，但工程层面积累了严重的技术债：

- 开机自启依赖的 `LSSharedFileList` API 已在 macOS 10.10 废弃，在 macOS 13+ 上失效；
- 三种终端各有一套 AppleScript 脚本（共 13 个），维护成本高，且 Ghostty 缺少对应的 Apple Events 权限；
- 构建产物没有代码签名与 notarization，现代 macOS 下会被 Gatekeeper 拦截；
- 核心逻辑全部堆在单个 `AppDelegate` 类中，几乎无自动化测试；
- 工程文件停留在 Xcode 10 时代，CI 仅有模板级构建。

本重构的目标是：**在不改变对外功能与配置兼容性的前提下，让应用在现代 macOS 上可构建、可安装、可运行，并具备可维护性与可测试性**。

## User Scenarios & Testing *(mandatory)*

> 本重构的"用户"包含两类：最终使用 Shuttle 的开发者/运维人员，以及维护这个仓库的开发者。以下按独立可验证的价值切片排序。

### User Story 1 - 应用在现代 macOS 上可正常安装与运行 (Priority: P1)

用户下载最新版 Shuttle 后，能够直接安装并启动，不会被系统拦截；勾选"开机自启"后，重启机器应用能自动运行。

**Why this priority**: 这是当前最紧迫的"能用"问题——旧 API 失效 + 无签名公证，已经导致新用户无法顺畅安装、老用户的自启失效。解决它才能让其余改造有意义。

**Independent Test**: 在一台 macOS 13+ 的干净机器上，下载并安装构建产物，验证（1）无 Gatekeeper「无法验证开发者」拦截；（2）应用能启动并出现状态栏图标；（3）开启"开机自启"后注销/重启，应用自动运行。

**Acceptance Scenarios**:

1. **Given** 一份已签名并公证的构建产物，**When** 用户在 macOS 13+ 上首次打开，**Then** 系统不再显示"来自身份不明开发者"警告，应用可正常启动。
2. **Given** 应用运行中且用户启用了"开机自启"，**When** 用户注销并重新登录，**Then** 应用自动启动且状态栏图标出现。
3. **Given** 应用运行中且用户关闭了"开机自启"，**When** 用户注销并重新登录，**Then** 应用不自动启动。

---

### User Story 2 - 三种终端都能被正确驱动 (Priority: P1)

用户把配置里的 `terminal` 设为 Terminal.app、iTerm2 或 Ghostty 三种之一，点击菜单项都能在对应终端里正确打开 SSH 连接或执行命令，且不触发自动化权限异常。

**Why this priority**: 终端驱动是 Shuttle 的核心功能；Ghostty 支持是近期 fork 加进来却没有配套权限的，属于"半成品"状态，同样在 P0 修复范围内。

**Independent Test**: 分别将 `terminal` 设为 Terminal.app、iTerm2、Ghostty，各点击一条 SSH 菜单项，验证命令在正确终端中运行；首次执行时授予自动化权限后不再重复弹授权异常。

**Acceptance Scenarios**:

1. **Given** `terminal` 为 Terminal.app，**When** 用户点击一条命令，**Then** 命令在 Terminal.app 的新 tab/窗口（按 `open_in` 配置）中运行。
2. **Given** `terminal` 为 iTerm2（stable/nightly），**When** 用户点击一条命令，**Then** 命令在 iTerm2 中按配置运行。
3. **Given** `terminal` 为 Ghostty，**When** 用户点击一条命令，**Then** 命令经 Ghostty 自身 CLI 在 Ghostty 中运行，且不依赖 Apple Events 自动化授权。

---

### User Story 3 - 配置解析与菜单构建行为无回归 (Priority: P1)

重构后，用户现有的 `~/.shuttle.json`（含嵌套菜单、`[aaa]` 排序标记、`[---]` 分隔符、`theme`/`title`/`inTerminal` 等字段）与 `~/.ssh/config` 主机解析结果，与重构前完全一致。

**Why this priority**: 重构最高风险就是引入行为回归，破坏大量存量用户的配置。必须把"无回归"作为一个独立可验证的切片，而不是隐藏在其他改造里。

**Independent Test**: 用一组固定的样例配置（含嵌套、排序、分隔符、SSH config 的 Host/Include/注释/通配等），对比重构前后生成的菜单结构（名称、层级、顺序、分隔符、命令）完全一致。

**Acceptance Scenarios**:

1. **Given** 一份含嵌套菜单与 `[aaa]`/`[---]` 标记的 JSON，**When** 应用加载菜单，**Then** 菜单层级、排序与分隔符与既有行为一致。
2. **Given** 一份含 Host、Include、注释、通配符的 `~/.ssh/config`，**When** 应用解析，**Then** 生成的主机菜单项与既有解析结果一致，通配与忽略规则照旧生效。
3. **Given** 一份语法错误的 JSON，**When** 应用加载，**Then** 菜单中显示可读的"配置解析错误"提示，且应用不崩溃。

---

### User Story 4 - 核心解析逻辑具备自动化测试 (Priority: P2)

配置读取、SSH config 解析、菜单构建、命令/参数生成等纯逻辑，从 UI 中解耦出来并被单元测试覆盖，可直接在 CI 中运行。

**Why this priority**: 测试是"敢继续改"的前提。把纯逻辑抽出来后，回归保护（User Story 3）才能自动执行，而不是靠手动比对。

**Independent Test**: 在 CI 上运行单元测试套件，覆盖配置解析、SSH config 解析、菜单构建等，全部通过。

**Acceptance Scenarios**:

1. **Given** 一套解析/构建逻辑的单元测试，**When** 在 CI 中执行，**Then** 测试全部通过且能在无 GUI 环境下运行。
2. **Given** 一个已拆分的解析模块，**When** 修改其内部实现，**Then** 不依赖启动完整应用即可验证行为正确。

---

### User Story 5 - 工程与发版现代化 (Priority: P2)

工程文件能由当前 Xcode 打开构建；CI 能自动产出签名并公证的 DMG 作为发布产物。

**Why this priority**: 这是可维护性与持续交付的基础，优先级低于"能跑"和"无回归"，但对长期健康同样关键。

**Independent Test**: 在 CI 上触发一次构建，验证生成签名+公证的 DMG 产物，并能在 macOS 13+ 上安装运行。

**Acceptance Scenarios**:

1. **Given** 工程文件已升级，**When** 用当前版本 Xcode 构建，**Then** 构建成功且无废弃 API 编译错误。
2. **Given** 一次 CI 运行，**When** 构建与打包流水线完成，**Then** 产出含签名与公证的发布 DMG。

---

### Edge Cases

- 用户的系统 < 最低部署目标，应用应给出明确提示而非静默崩溃。
- 某终端未安装时，点击菜单项应给出可读提示（而非无响应或崩溃）。
- 用户首次执行、自动化权限未授予时，系统提示能正确引导用户开启权限。
- SSH config 含空文件、编码异常、循环 Include 时，解析应安全终止。
- 配置文件为新旧混合语法/损坏时，回退到上一次成功配置或报错，不崩溃。
- 开机自启状态与系统真实状态不一致（用户在系统设置里手动改了登录项）时，应用应能反映真实状态。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 应用 MUST 能在 macOS 最低部署目标及更高版本上构建、启动并显示状态栏图标。
- **FR-002**: 开机自启 MUST 使用 `SMAppService`（受支持的登录项机制，替换已废弃的 `LSSharedFileList`），且 MUST 与系统设置中的登录项状态保持一致；最低部署目标为 macOS 13 Ventura。
- **FR-003**: 构建产物 MUST 经过代码签名与 notarization，使 macOS Gatekeeper 不再拦截。
- **FR-004**: Ghostty 经由其自身 CLI 驱动（不经 Apple Events），应用权限清单 MUST 移除针对 Ghostty 的 Apple Events 授权，仅保留控制 Terminal.app 所需的自动化授权。
- **FR-005**: 应用 MUST 持续支持 Terminal.app、iTerm2（stable/nightly）与 Ghostty 三种终端的命令派发，行为与既有功能一致。
- **FR-006**: 现有 JSON 配置格式与字段语义 MUST 保持 100% 向后兼容，不改变任何字段含义，存量用户配置零迁移成本。
- **FR-007**: `AppDelegate` 中的配置读取、SSH config 解析、菜单构建、命令派发等职责 MUST 被拆分到独立、单一职责的模块中。
- **FR-008**: 拆分后的解析与构建逻辑 MUST 产生与重构前完全一致的菜单结果（无回归）。
- **FR-009**: 项目 MUST 统一启用 ARC，去除手动内存管理与非 ARC 编译开关。
- **FR-010**: 死代码（无使用的宏、恒真分支、无效权限检查等）MUST 被移除。
- **FR-011**: AppleScript 脚本集 MUST 被务实收敛以减少维护面：iTerm2 改用 `iterm2://` URL scheme、Ghostty 改用其自身 CLI，仅 Terminal.app 保留 AppleScript。
- **FR-012**: 配置解析、SSH config 解析、菜单构建等纯逻辑 MUST 有可在无 GUI 环境运行的单元测试。
- **FR-013**: 工程文件 MUST 升级到当前 Xcode 可识别的最新格式，并移除对已废弃 API 的编译依赖。
- **FR-014**: CI MUST 从"仅构建"升级为包含单测、签名、公证、DMG 打包的完整流水线。

### Key Entities

- **配置柄（Config Source）**: 表示 JSON 主配置、可选第二 JSON 配置、`~/.ssh/config` 的抽象，含修改时间戳用于热更新判定。
- **菜单节点（Menu Node）**: 表示菜单中的目录节点与叶子节点，叶子携带要显示的名称与待执行命令。
- **终端命令（Terminal Command）**: 表示一次待派发的命令，含命令文本、目标终端类型、open 方式（tab/new/current/virtual）、主题、标题等参数。
- **终端后端（Terminal Backend）**: 表示对某一种终端（Terminal/iTerm2/Ghostty）如何发起命令/会话的策略。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 在 macOS 13+ 干净环境上，用户从下载到启动应用全程无「无法验证开发者」拦截，安装成功率 100%。
- **SC-002**: 开启"开机自启"后，重启机器应用自动运行的可靠率达到 100%（在受支持的最低系统及以上）。
- **SC-003**: 三种终端（Terminal.app、iTerm2、Ghostty）的命令派发在验收样例 100% 通过，无自动化权限异常。
- **SC-004**: 用固定样例配置对比，重构前后生成的菜单结构 100% 一致（零回归）。
- **SC-005**: 解析/构建核心逻辑的单元测试行覆盖率达到 ≥ 70%，且在 CI 上稳定通过。
- **SC-006**: 一次 CI 构建可产出签名+公证的 DMG，无需人工步骤。
- **SC-007**: 构建过程中对已废弃 API 的编译告警降至 0。

## Assumptions

- 最低部署目标确定为 macOS 13（Ventura），因此 `SMAppService` 可直接用于开机自启，无需降级路径。
- 现有 JSON 配置格式是被广泛使用、不宜破坏的公开契约，按 100% 完全兼容处理。
- 终端驱动仍以 AppleScript 或终端自带机制为准，不引入第三方运行时依赖（如 Swift Package Manager 外部库），以保持单一二进制、低资源占用。
- 签名与公证依赖开发者具备有效的 Apple Developer 证书与公证凭据（由仓库所有者/发版者提供）。
- 单元测试面向纯逻辑（解析、构建、命令生成），终端实际控制与 AppleScript 执行属集成/手动测试范畴。
- 四语言本地化（英/西/法/简中）与现有图标资源保持不变。