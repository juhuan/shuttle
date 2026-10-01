# 契约：JSON 配置 Schema（`~/.shuttle.json`）

> 本契约是 Shuttle 的**公开用户接口**，FR-006 要求 100% 向后兼容。任何字段语义变化都视为破坏性变更，禁止发生。重构后的实现必须逐字段复刻本节语义。

## 顶层字段

| 键 | 类型 | 语义 | 缺省/回退 |
|---|---|---|---|
| `editor` | string | 打开配置的编辑器；`default` 表示用系统默认应用 | `default` |
| `launch_at_login` | bool | 是否开机自启 | `false` |
| `terminal` | string | 消息终端：`Terminal.app` / `iTerm` / `Ghostty.app` | `Terminal.app` |
| `iTerm_version` | string | iTerm 版本：`stable` / `nightly` | — |
| `default_theme` | string | 全局默认 terminal 主题 | 无 |
| `open_in` | string | 默认打开方式：`tab` / `new` / `current` | `tab` |
| `show_ssh_config_hosts` | bool | 是否合并 `~/.ssh/config` 主机 | `true`（缺省视为 true）|
| `ssh_config_ignore_hosts` | string[] | 精确匹配则忽略的 SSH 主机名 | `[]` |
| `ssh_config_ignore_keywords` | string[] | 名称包含则忽略的关键字 | `[]` |
| `hosts` | array | 菜单树（见下） | `[]` |
| `_comments` | string[] | 说明性注释，忽略 | 忽略 |

> 字段键统一 `lowercaseString` 后匹配（与现状一致）。`terminal`/`editor`/`iTerm_version`/`open_in` 的值也全部小写化后比较。

## `hosts` 菜单树结构

`hosts` 是元素的数组，元素可为以下任一：

### 叶子（命令项）

```json
{ "cmd": "ssh user@host", "name": "SSH 到某机" }
```

- `cmd`（必需）：在终端执行的命令。
- `name`（必需）：菜单显示名；若含排序/分隔标记见「名称标记」。
- `theme`（可选）：该会话主题，覆盖 `default_theme`。
- `title`（可选）：终端窗口/tab 标题，覆盖 `name`。
- `inTerminal`（可选）：`tab` / `new` / `current` / `virtual`，覆盖 `open_in`。

### 目录（嵌套菜单）

元素为「单键对象」，键为目录名、值为子元素数组：

```json
{ "我的服务器": [ { "cmd": "...", "name": "..." } ] }
```

- 目录键名同样遵循「名称标记」规则。

## 名称标记（排序 / 分隔符）

- 名称含形如 `[xxx]`（方括号 + 三个小写字母，如 `[aaa]`）→ 去除该标记，仅作排序信号（目录与叶子均按去除标记后的名称 `localizedCaseInsensitiveCompare:` 排序）。
- 名称含 `[---]`（方括号 + 三个连字符）→ 去除该标记，并在该项之后插入一个分隔符。
  - `[aaa]` 与 `[---]` 同时存在 → 两者都去除并插入分隔符。

## 兼容性红线

1. 不允许重命名/删除任何顶层键，不允许改变 `cmd`/`name`/`theme`/`title`/`inTerminal` 的含义。
2. `open_in`/`inTerminal` 的取值集合固定为 `tab`/`new`/`current`/`virtual`；非法值行为与现状一致（弹错误并终止）。
3. `show_ssh_config_hosts` 缺省仍视为启用；显式 `false` 才关闭。
4. 语法错误 JSON（`NSJSONSerialization` 返回 nil）→ 菜单显示「配置解析错误」，应用不崩溃。

## 第二配置文件

若存在 `~/.shuttle-alt.json`（或 `~/.shuttle-alt.path` 指向的文件），其 `hosts` 数组**追加**到主配置 `hosts` 之后（`addObjectsFromArray`），其余顶层字段以主配置为准。