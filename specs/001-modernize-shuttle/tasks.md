# Tasks: Shuttle 现代化大重构

**Input**: 设计文档来自 `/specs/001-modernize-shuttle/`
**Prerequisites**: plan.md（技术栈/结构）、spec.md（用户故事）、research.md（决策）、data-model.md（实体）、contracts/（契约）、quickstart.md（验证）

**Tests**: 已启用 —— spec 的用户故事 4（FR-012）明确要求核心解析/构建逻辑具备可在无 GUI 环境运行的单元测试（SC-005 行覆盖 ≥70%）。

**组织方式**: 按用户故事分组，支持每个故事的独立实现与验证。第 1/2 阶段为 Setup 与 Foundational；第 3~7 阶段按优先级对应 US1~US5；第 8 阶段为收尾。

## 格式: `[ID] [P?] [Story] Description`

- **[P]**: 可并行（不同文件、无未完成依赖）
- **[Story]**: US1~US5 对应 spec.md 中的用户故事；Setup/Foundational/Polish 无 Story 标签

---

## Phase 1: Setup（工程基础设施）

**Purpose**: 将工程基础一次配到位，为后续所有工作扫清路障。

- [X] T001 [P] 将 `Shuttle.xcodeproj/project.pbxproj` 中所有 `MACOSX_DEPLOYMENT_TARGET = 10.15` 改为 `13.0`，并更新 `LastUpgradeCheck`，使工程以现代 Xcode 识别（FR-013，最低部署目标 macOS 13）。
- [X] T002 [P] 为工程生成共享 scheme `Shuttle.xcodeproj/xcshareddata/xcschemes/Shuttle.xcscheme`（当前无显式 scheme，CI 依赖默认 target 推断，见 research R11）。
- [X] T003 [P] 新增 `ShuttleTests` 单元测试 target 骨架：在 `Shuttle.xcodeproj/project.pbxproj` 注册 `com.apple.product-type.bundle.unit-test` target、创建 `ShuttleTests/` 目录与测试 Info.plist（先留空，供 US4 填充）。

---

## Phase 2: Foundational（共享类型，阻断性前置）

**Purpose**: 全项目共享的值对象与协议，US2/US3 都依赖它们。纯类型抽取，不改变行为。

**⚠️ CRITICAL**: US2/US3 依赖本阶段产物；US1 仅依赖 Setup。

- [X] T004 [P] 新建 `Shuttle/Terminal/SHTerminalCommand.h/.m`：定义 `command/theme/title/openMode(tab|new|current|virtual)/terminalType/fallbackName` 字段，并迁入 openHost 中 theme→title→openMode 的归一化顺序（严格复刻 data-model.md 第 5 节），替换 `¬_¬` 定界字符串。
- [X] T005 [P] 新建 `Shuttle/Menu/SHMenuNode.h/.m`：定义 `title/isLeaf/command/children/appendSeparator` 字段（data-model.md 第 4 节）。
- [X] T006 [P] 新建 `Shuttle/Terminal/SHTerminalBackend.h`：声明协议方法 `- (BOOL)dispatchCommand:(SHTerminalCommand *)command error:(NSError **)error`（data-model.md 第 6 节）。
- [X] T007 [P] 新建 `Shuttle/Config/SHShuttleConfig.h/.m`：JSON 根值对象，字段与校验严格遵循 `contracts/json-config-schema.md`（`terminal/editor/iTerm_version/open_in` 一律 `lowercaseString`）。
- [X] T008 将 T004~T007 的新文件注册进 `Shuttle.xcodeproj/project.pbxproj` 的 Sources 构建阶段，确认工程仍可编译通过。

**Checkpoint**: 基础类型就绪，可进入用户故事实现。

---

## Phase 3: User Story 1 - 应用在现代 macOS 上可安装与运行 (Priority: P1) 🎯 MVP

**Goal**: 用 `SMAppService` 替换失效的 `LSSharedFileList` 开机自启。

**Independent Test**: 在 macOS 13+ 打开应用出现状态栏图标；勾选「开机自启」后注销/重登应用自动运行；关闭自启后不自动运行（quickstart.md 场景 1）。

- [X] T009 [US1] 新建 `Shuttle/SHLaunchAtLogin.h/.m`：以 `[SMAppService mainApp]` 实现读取 `status`、`registerAndReturnError:`、`unregisterAndReturnError:`（research R2）。
- [X] T010 [US1] 删除 `Shuttle/LaunchAtLoginController.h/.m`，并在 `Shuttle.xcodeproj/project.pbxproj` 移除其 Sources 条目及 `COMPILER_FLAGS = "-fno-objc-arc"`（全项目统一 ARC，FR-009）。
- [X] T011 [US1] 在 `Shuttle/AppDelegate.m` 中将 `launchAtLoginController` 的初始化与 `loadMenu` 中 `launch_at_login` 的读写替换为 `SHLaunchAtLogin`，并保持 MainMenu.xib 菜单项的既有绑定行为一致。

**Checkpoint**: 自启链路走受支持 API，应用可正常构建运行。

---

## Phase 4: User Story 2 - 三种终端都能被正确驱动 (Priority: P1)

**Goal**: Terminal.app / iTerm2 / Ghostty 三种终端 + virtual 模式正确派发，且收敛 AppleScript 与授权。

**Independent Test**: 分别将 `terminal` 设为 Terminal.app、iTerm、Ghostty.app，点击命令在对应终端运行；`virtual` 后台运行不弹终端；无自动化权限异常（quickstart.md 场景 2）。

- [X] T012 [P] [US2] 新建 `Shuttle/Terminal/SHTerminalAppBackend.h/.m`：封装 AppleScript 调用（迁移 AppDelegate 的 `runScript:`），驱动 `terminal-new-window/current-window/new-tab-default` 三个脚本（research R5）。
- [X] T013 [P] [US2] 新建 `Shuttle/Terminal/SHITermBackend.h/.m`：构造 `iterm2:/command?c=<command>` 命令 URL 并以 `[[NSWorkspace sharedWorkspace] openURL:]` 派发（research R3，注意实现阶段复核 tab/new/current 参数）。
- [X] T014 [P] [US2] 新建 `Shuttle/Terminal/SHGhosttyBackend.h/.m`：用 `NSTask` 调 `ghostty +new-window|+new-tab -e <command>`（research R4，current 模式降级语义需明确）。
- [X] T015 [P] [US2] 新建 `Shuttle/Terminal/SHVirtualBackend.h/.m`：用 `NSTask` 执行 `screen -d -m -S <title> <command>`（research R6）。
- [X] T016 [US2] 重构 `Shuttle/AppDelegate.m` 的 `openHost:`：用 `SHTerminalCommand` + 后端策略（按 terminalType/openMode 选择）替换内联分支，并删除 `runScript:` 方法。
- [X] T017 [US2] 删除冗余脚本并在 `Shuttle.xcodeproj/project.pbxproj` Resources 阶段移除：`Shuttle/apple-scpt/iTerm2-*.scpt`、`ghostty-*.scpt`、`virtual-with-screen.scpt`；同步删除 `apple-scripts/` 下对应源与 `compile-*.sh`。
- [X] T018 [US2] 收敛 `Shuttle/Shuttle.entitlements` 仅保留 `com.apple.terminal` 的 Apple Events 授权（移除 `com.googlecode.iterm2`、`com.mitchellh.ghostty`）；同步清理 `Shuttle/Shuttle-Info.plist` 的自动化描述措辞（research R12）。

**Checkpoint**: 三终端 + virtual 派发收敛完成，授权最小化。

---

## Phase 5: User Story 3 - 配置解析与菜单构建行为无回归 (Priority: P1)

**Goal**: JSON/SSH 解析与菜单构建与重构前逐项一致（FR-008/SC-004）。

**Independent Test**: 用含嵌套、`[aaa]`、`[---]`、theme/title/inTerminal 的样例 JSON，以及含 Host/Include/注释/通配符的 `~/.ssh/config`，比对重构前后菜单的名称/层级/顺序/分隔符/命令一致（quickstart.md 场景 3）。

- [X] T019 [P] [US3] 新建 `Shuttle/Config/SHConfigSource.h/.m`：实现配置/SSH 路径解析（`.shuttle.path`/`.shuttle-alt.path`/默认回退）与 mtime 热更新判定 `needUpdate`，严格复刻 awakeFromNib/needUpdateFor/getMTimeFor（data-model.md 第 1 节）。
- [X] T020 [P] [US3] 新建 `Shuttle/Config/SHSSHConfigParser.h/.m`：按 `contracts/ssh-config-parsing.md` 实现逐行正则解析、Host 别名、Include 递归合并、`shuttle.*` 注释元数据、空文件/编码异常安全终止。
- [X] T021 [P] [US3] 新建 `Shuttle/Menu/SHMenuBuilder.h/.m`：将 hosts 数组构建为 SHMenuNode 树——目录/叶子 `localizedCaseInsensitiveCompare:` 排序、`[aaa]` 与 `[---]` 标记去除/分隔符、SSH 主机注入（含 `/` 路径细分与忽略规则），复刻 buildMenu/separatorSortRemoval/loadMenu 注入逻辑（data-model.md 第 4 节）。
- [X] T022 [US3] 在尚未重写 AppDelegate 前，用当前（旧）实现运行一组固定样例 JSON 与 `~/.ssh/config`（含嵌套/`[aaa]`/`[---]`/theme/title/inTerminal 与 Host/Include/注释/通配符），将生成的菜单结构（名称/层级/顺序/分隔符/命令）序列化为 `ShuttleTests/Fixtures/` 下的 golden fixture（SC-004 无回归基线）。
- [X] T023 [US3] 重构 `Shuttle/AppDelegate.m` 的 `awakeFromNib`/`loadMenu`/`menuWillOpen:`，改为使用 SHConfigSource/SHShuttleConfig/SHSSHConfigParser/SHMenuBuilder，产出等价的 NSMenu（无回归）。

**Checkpoint**: 配置解析与菜单构建模块化且行为零回归（含 golden 基线）。

---

## Phase 6: User Story 4 - 核心解析逻辑具备自动化测试 (Priority: P2)

**Goal**: 纯逻辑被单元测试覆盖，可在无 GUI CI 运行。

**Independent Test**: `xcodebuild test` 在 CI 上全绿（quickstart.md「运行单元测试」）。

- [X] T024 [P] [US4] 新建 `ShuttleTests/SHSSHConfigParserTests.m`：覆盖 Host 别名/Include 递归/注释跳过/`shuttle.*` 元数据/通配符与 `.` 前缀忽略。
- [X] T025 [P] [US4] 新建 `ShuttleTests/SHMenuBuilderTests.m`：覆盖嵌套菜单/`[aaa]` 排序/`[---]` 分隔符/目录与叶子排序/SSH 主机注入路径细分。
- [X] T026 [P] [US4] 新建 `ShuttleTests/SHConfigSourceTests.m`：覆盖路径解析三态（`.shuttle.path`/默认回退/`.shuttle-alt`）与 mtime 变更判定。
- [X] T027 [P] [US4] 新建 `ShuttleTests/SHShuttleConfigTests.m`：覆盖字段 lowercase、缺省回退、语法错误 JSON 安全返回。
- [X] T028 [P] [US4] 新建 `ShuttleTests/SHTerminalCommandTests.m`：覆盖 theme→title→openMode 归一化顺序与非法 openMode 报错。
- [X] T029 [US4] 新建 `ShuttleTests/SHMenuBuilderGoldenTests.m`：加载 `ShuttleTests/Fixtures/` 的 golden fixture，断言 `SHMenuBuilder` 对同一批样例的产出与重构前逐项一致（SC-004 零回归）。
- [X] T030 [US4] 在 `Shuttle.xcodeproj/project.pbxproj` 为测试 target 开启代码覆盖率（`CLANG_ENABLE_CODE_COVERAGE`），确认解析/构建核心逻辑行覆盖 ≥70%（SC-005）。

**Checkpoint**: 回归保护自动可执行。

---

## Phase 7: User Story 5 - 工程与发版现代化 (Priority: P2)

**Goal**: 工程可被当前 Xcode 构建；CI 产出签名+公证 DMG。

**Independent Test**: 一次 CI 运行产出已签名并公证的 DMG，可在 macOS 13+ 安装运行（quickstart.md 场景 5）。

- [X] T031 [P] [US5] 重写 `.github/workflows/objective-c-xcode.yml` 为完整流水线：checkout → `xcodebuild test` → Release 签名构建 → `xcrun notarytool submit` → `xcrun stapler staple` → `hdiutil` 打 DMG。
- [X] T032 [P] [US5] 更新 `build.sh`：加入 codesign、notarytool、stapler 步骤，与 CI 一致（本地发版路径）。
- [X] T033 [US5] 确认构建对已废弃 API 的编译告警归零（`LSSharedFileList` 等随 T010 删除自然消失），并据此清理残留（SC-007）。
- [X] T034 [US5] 运行 quickstart.md 端到端清单（三终端 + 自启 + 无回归比对 + 发版 DMG）做整体验收。

**Checkpoint**: 可持续交付闭环完成。

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: 跨故事的收尾。

- [X] T035 [P] 移除死代码：`Shuttle/AppDelegate.m` 的 `checkAppleEventsPermission`（恒真分支）、未再使用的 `requestAppleEventsPermission`、顶部 `SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO` 宏（FR-010）。
- [X] T036 [P] 更新 `README.md` 与 `CHANGELOG.md`：说明新最低系统 macOS 13.0、精简后的终端支持（iTerm2 via URL scheme / Ghostty via CLI）与发版方式。

---

## Dependencies & Execution Order

### 阶段依赖

- **Setup (Phase 1)**: 无依赖，立即开始。
- **Foundational (Phase 2)**: 依赖 Setup，**阻断 US2/US3**（US1 仅依赖 Setup）。
- **User Stories (Phase 3~7)**: P1 故事（US1/US2/US3）先于 P2 故事（US4/US5）。
- **Polish (Phase 8)**: 依赖所有目标故事完成。

### 用户故事依赖

- **US1 (P1)**: 仅依赖 Setup，独立可测（自启链路）。
- **US2 (P1)**: 依赖 Foundational（SHTerminalCommand/SHTerminalBackend），独立可测（三终端派发）。
- **US3 (P1)**: 依赖 Foundational（SHShuttleConfig/SHMenuNode），独立可测（无回归）。与 US1/US2 共享 AppDelegate，建议顺序执行以降低同一文件冲突。
- **US4 (P2)**: 依赖 US2/US3 的模块（Parser/Builder/Command/ConfigSource）与 US3 的 golden fixture（T022）。
- **US5 (P2)**: 依赖 US1（自启）+ US2（脚本收敛）后，工程面收敛完成方能稳定签名打包。

### 故事内顺序

- 模型/纯逻辑抽取 → 后端/构建器实现 → AppDelegate 接线 → 验证。
- US3 顺序关键：T019~T021 建模块 → **T022 先捕获旧实现 golden 基线** → T023 重写 AppDelegate（顺序不能颠倒，否则失去基线）。
- US4：先写测试文件（可先 FAIL），再接覆盖率开关。

### 并行机会

- Setup 的 T001/T002/T003 可并行。
- Foundational 的 T004~T007 可并行（不同新文件），T008 收口。
- US2 的 T012~T015 四个后端可并行（不同新文件），T016 接线收口。
- US3 的 T019~T021 三个模块可并行，T022/T023 顺序执行收口。
- US4 的 T024~T028 五个测试文件可并行。
- 注释：T011/T016/T023 都改 `Shuttle/AppDelegate.m`，**不要并行**；建议按 US1→US2→US3 顺序接线。

---

## Parallel Example: User Story 2（后端策略并行）

```bash
# 四个后端相互独立，可同时开工：
Task: "新建 Shuttle/Terminal/SHTerminalAppBackend.h/.m（AppleScript 驱动 Terminal.app）"
Task: "新建 Shuttle/Terminal/SHITermBackend.h/.m（iterm2:// URL scheme）"
Task: "新建 Shuttle/Terminal/SHGhosttyBackend.h/.m（ghostty CLI）"
Task: "新建 Shuttle/Terminal/SHVirtualBackend.h/.m（screen）"
# 完成后统一接线：
Task: "重构 Shuttle/AppDelegate.m 的 openHost: 使用后端策略"
```

---

## Implementation Strategy

### MVP First（仅 US1）

1. 完成 Phase 1（Setup）+ Phase 2（Foundational）。
2. 完成 Phase 3（US1：SMAppService 自启）。
3. **停下验证**：构建运行 + 自启开关独立验证。
4. 可先行演示/交付「可安装、可运行、自启可用」的最小闭环。

### 增量交付

1. Setup + Foundational → 基础就绪。
2. + US1（自启）→ 验证 → 可交付（MVP）。
3. + US2（三终端）→ 验证 → 增量交付。
4. + US3（无回归 + golden 基线）→ 验证（关键回归门禁）。
5. + US4（测试）→ CI 回归保护生效。
6. + US5（签名/公证/DMG）→ 可持续发版闭环。

### 多人并行策略

- 团队一起完成 Setup + Foundational。
- Foundational 完成后：A 做 US2，B 做 US3（二者改不同模块文件），US1 因只改 AppDelegate 与 LaunchAtLogin 可独立于 A/B 进行。
- US4 需等 US2/US3 模块与 US3 的 golden fixture 稳定后再补测试；US5 最后统一收口。

---

## Notes

- `[P]` = 不同文件、无未完成依赖；`[Story]` 标签用于追溯。
- 每个用户故事应能独立完成并验证。
- 提交时机：每完成一个任务或逻辑任务组即提交；在每个 Checkpoint 停下独立验证。
- 避免：模糊任务、同文件并行冲突、破坏故事独立性的跨故事依赖。
- 实现阶段务必回读 quickstart.md 的「已知边界」两处开放项（iTerm2 参数映射 / Ghostty current 降级）。