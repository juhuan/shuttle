# Implementation Plan: Shuttle 现代化大重构

**Branch**: `001-modernize-shuttle` | **Date**: 2026-10-01 | **Spec**: [spec.md](./spec.md)

**Input**: 来自 `/specs/001-modernize-shuttle/spec.md` 的功能规格。

## Summary

将十余年未实质更新的 Shuttle（Objective-C 菜单栏应用）做一次完整重构，目标是"不改变对外功能与配置兼容性的前提下，能在 macOS 13+ 上构建/安装/运行，并具备可维护性与可测试性"。

技术路径由 [research.md](./research.md) 收敛为五条主线：

1. **替换失效 API**：开机自启从废弃的 `LSSharedFileList` 迁移到 `SMAppService.mainApp`（需 macOS 13+）。
2. **拆分上帝对象**：把 `AppDelegate`（~1400 行）拆成配置加载 / SSH config 解析 / 菜单构建 / 终端派发四类单一职责模块，用轻量模型对象替换 `¬_¬` 定界字符串传参。
3. **收敛 AppleScript 与授权**：iTerm2 改用 `iterm2://` URL scheme、Ghostty 改用其 CLI，仅 Terminal.app 保留 AppleScript；`virtual` 模式用原生 `screen` 命令实现。
4. **补齐测试**：新增 XCTest 单元测试 target，覆盖配置解析、SSH config 解析、菜单构建、命令/参数生成等纯逻辑。
5. **工程与发版现代化**：升级 `MACOSX_DEPLOYMENT_TARGET` 到 13.0、统一 ARC、CI 升级为"单测 + 签名 + 公证 + DMG"完整流水线。

## Technical Context

**Language/Version**: Objective-C（统一 ARC），Cocoa/AppKit。无 Swift，无第三方依赖。

**Primary Dependencies**: 仅系统 `Cocoa.framework`；Apple Events 自动化（仅 Terminal.app）；`SMAppService`（ServiceManagement，macOS 13+）；`screen`（系统自带，virtual 模式）。

**Storage**: 文件系统。`~/.shuttle.json`（主配置）、`~/.shuttle-alt.json`（可选第二配置）、`~/.shuttle.path`/`~/.shuttle-alt.path`（自定义路径指针）、`~/.ssh/config` 与 `/etc/ssh*`（SSH 主机）。无数据库。

**Testing**: 新增 XCTest 单元测试 target（`ShuttleTests`），跑纯逻辑、可在无 GUI 的 CI 环境执行；保留现有 `tests/test_ghostty_support.py` 为兼容性参考。目标行覆盖率 ≥ 70%（SC-005）。

**Target Platform**: macOS 13（Ventura）及以上，`arm64` + `x86_64` 双架构。

**Project Type**: desktop-app（`LSUIElement=YES` 的菜单栏/状态栏应用）。

**Performance Goals**: 菜单打开即构建；配置热更新靠 mtime 判定（`menuWillOpen:` 时 diff，仅变更时重建）。无高频/吞吐指标。

**Constraints**: 单一二进制、零第三方运行时依赖、低资源占用；四语言本地化（en/es/fr/zh-Hans）与图标资源保持不变；JSON 配置 100% 向后兼容（存量用户零迁移）。

**Scale/Scope**: 小规模应用。核心重构集中在 6 个新模块 + 1 个重写文件 + 1 个测试 target + 工程/CI 配置。

## Constitution Check

*GATE: Phase 0 研究前必须通过；Phase 1 设计后需复检。*

`.specify/memory/constitution.md` 仍为未填写的模板，**无项目专属宪法条款可依**。因此本计划的约束门禁改由规格文件中的强制性需求承担，按标准工程默认执行：

| 门禁（GATE） | 状态 | 依据 |
|---|---|---|
| JSON 配置 100% 向后兼容、零迁移 | 通过（视为不可协商） | FR-006、SC-004 |
| 重构后菜单结构无回归 | 通过 | FR-008 |
| 全项目统一 ARC | 通过 | FR-009 |
| 无第三方运行时依赖 | 通过 | Assumptions |
| 纯逻辑（解析/构建/命令生成）可被单测覆盖 | 通过 | FR-012 |
| 死代码移除 | 通过 | FR-010 |

> Phase 1 复检：上述门禁在设计产物（data-model.md、contracts/）中均被显式编码为契约，无新增违规，**复检通过**。未发现需要「Complexity Tracking」记录的、超出规格的复杂度引入。

## Project Structure

### Documentation (this feature)

```text
specs/001-modernize-shuttle/
├── plan.md              # 本文件
├── research.md          # Phase 0 输出：技术决策与理由
├── data-model.md        # Phase 1 输出：实体与状态
├── quickstart.md        # Phase 1 输出：验证/运行指南
├── contracts/           # Phase 1 输出：对外接口契约
│   ├── json-config-schema.md
│   └── ssh-config-parsing.md
└── tasks.md             # Phase 2 输出（/speckit-tasks，本命令不生成）
```

### Source Code (repository root)

```text
Shuttle/
├── AppDelegate.h/.m              # 变薄：app 生命周期 + 状态栏 + menu delegate
├── Config/
│   ├── SHConfigSource.h/.m       # 配置路径解析(.shuttle.path 等) + 读取 + mtime
│   ├── SHShuttleConfig.h/.m      # JSON 配置值对象
│   └── SHSSHConfigParser.h/.m    # ~/.ssh/config + /etc/ssh* 解析
├── Menu/
│   ├── SHMenuNode.h/.m           # 菜单树节点模型(替换 ¬_¬ 字符串)
│   └── SHMenuBuilder.h/.m        # hosts 数组 -> NSMenu(排序/分隔符/[aaa]/[---])
├── Terminal/
│   ├── SHTerminalCommand.h/.m    # 待派发命令值对象
│   ├── SHTerminalBackend.h       # 终端派发策略协议
│   ├── SHTerminalAppBackend.h/.m # Terminal.app (AppleScript)
│   ├── SHITermBackend.h/.m       # iTerm2 (iterm2:// URL scheme)
│   ├── SHGhosttyBackend.h/.m     # Ghostty (CLI)
│   └── SHVirtualBackend.h/.m     # virtual (原生 screen)
├── SHLaunchAtLogin.h/.m          # 重写: SMAppService.mainApp + ARC
├── LaunchAtLoginController.h/.m  # 删除(废弃 API 实现)
├── apple-scpt/                   # 收敛: 仅保留 terminal-*.scpt + virtual 移除
└── ...（本地化/图标/AboutWindowController 不变）

ShuttleTests/
├── SHSSHConfigParserTests.m
├── SHMenuBuilderTests.m
├── SHConfigSourceTests.m
└── SHShuttleConfigTests.m
```

**Structure Decision**: 单一 Xcode project（沿用现有 `Shuttle.xcodeproj`），在 `Shuttle/` 下按职责建立 `Config` / `Menu` / `Terminal` 子目录分组；新增平行测试 target `ShuttleTests`。不引入 Swift Package Manager、workspace 或多 module，保持单一二进制与低复杂度一致。

## Complexity Tracking

> 无宪法违规需要论证。本表留空。