# Data Model: Shuttle 配置与菜单构建

本文档定义重构后的核心实体、字段、关系、校验规则与状态流转，作为 `tasks.md` 实现与 `contracts/` 契约的输入。所有模型均为 Objective-C 类（对象前缀 `SH`），对应 plan.md 的目录分组。

## 实体总览

| 实体 | 职责 | 来源 |
|---|---|---|
| `SHConfigSource` | 配置/SSH 文件路径解析、读取、mtime 热更新判定 | 重构自 AppDelegate.awakeFromNib / needUpdateFor / getMTimeFor |
| `SHShuttleConfig` | JSON 配置的值对象（根） | 重构自 loadMenu 前半段 |
| `SHSSHConfigParser` | `~/.ssh/config` 与 `/etc/ssh*` 解析为主机字典 | 抽自 parseSSHConfigFile / parseSSHConfig |
| `SHMenuNode` | 菜单树节点（目录/叶子） | 替换 `¬_¬` 字符串 + NSMenu 直建 |
| `SHTerminalCommand` | 一次待派发的命令 | 替换 `¬_¬` 定界字符串 |
| `SHTerminalBackend`（协议）| 终端派发策略 | 重构自 openHost 的分支派发 |

## 1. SHConfigSource

- **字段**: `jsonPath`（主配置绝对路径）、`altJsonPath`（第二配置绝对路径）、`parseAltJSON`(BOOL)、`sshConfigUserPath`、`sshConfigSystemPath`、以及各路径的 `mtime`(NSDate)。
- **行为**: `needUpdate`（比较局部 mtime 与磁盘 mtime，仅在变更时返回 YES）。
- **路径解析规则**（100% 兼容）:
  1. 若存在 `~/.shuttle.path`，读取其内容（trim 空白）作为 `jsonPath`；否则 `~/.shuttle.json`（不存在则从 bundle `shuttle.default.json` 拷贝一份）。
  2. 若存在 `~/.shuttle-alt.path`，其内容为 `altJsonPath` 且 `parseAltJSON=YES`；否则用 `~/.shuttle-alt.json`，存在则 `parseAltJSON=YES`，否则 NO。
  3. SSH：`/etc/ssh_config` 或 `/etc/ssh/ssh_config` 二者取一（`/etc/ssh_config` 优先），用户级 `~/.ssh/config` 覆盖。

## 2. SHShuttleConfig（JSON 根值对象）

- **字段**（均以 current 代码语义为准，见 contracts/json-config-schema.md）:

| 字段 | 类型 | 默认/回退 | 备注 |
|---|---|---|---|
| `terminal` | NSString(lowercased) | `Terminal.app` | 决定后端类型 |
| `editor` | NSString(lowercased) | `default` | `default`=系统默认打开 |
| `iTerm_version` | NSString(lowercased) | — | `stable`/`nightly`（兼容保留，见 R3）|
| `open_in` | NSString(lowercased) | `tab` | `tab`/`new`/`current` |
| `default_theme` | NSString | nil | 叶子 theme 缺省时回退 |
| `launch_at_login` | BOOL | NO | 写入 SMAppService 状态 |
| `hosts` | NSArray | 空 | 嵌套菜单树 |
| `show_ssh_config_hosts` | BOOL(派生) | YES | 缺省按 YES（含 wildcard 时除外，见 3）|
| `ssh_config_ignore_hosts` | NSArray | 空 | 精确匹配名忽略 |
| `ssh_config_ignore_keywords` | NSArray | 空 | 名包含关键字忽略 |

- **校验规则**: terminal/editor/iTerm_version/open_in 一律 `lowercaseString` 后再用（保持与现状一致）；JSON 解析失败（nil）→ 菜单显示「Error parsing config」且不崩溃（US3 场景 3）。

## 3. SHSSHConfigParser

- **输出**: `NSDictionary<NSString, NSDictionary*>`，key=Host 首个别名，值含可选的 `name`（来自 `#shuttle.name` 注释）等元数据。
- **解析规则**（无回归，详见 contracts/ssh-config-parsing.md）:
  - 逐行正则 `^(#?)[ \t]*([^ \t=]+)[ \t=]+(.*)$`，取 1=注释标记、2=键、3=值。
  - `Host` 开新段：按空白切别名、取首个为 key。
  - `Include` 递归合并（相对路径相对当前文件目录展开）。
  - 注释且 key 已存在且前缀 `shuttle.` → 写入 `servers[key][前缀截断后的名]=值`（如 `#shuttle.name`）。
  - 空文件/编码异常/循环 Include：安全终止（Edge Cases）。

## 4. SHMenuNode

- **字段**: `title`(NSString)、`isLeaf`(BOOL)、`command`(SHTerminalCommand?)（叶子）、`children`(NSArray\<SHMenuNode\>?)（目录）、`appendSeparator`(BOOL)。
- **构建语义**（无回归核心）:
  - 目录按 `title` 的 `localizedCaseInsensitiveCompare:` 排序；叶子同理。
  - 名称含 `[aaa]`（三小写字母）→ 去除该标记；含 `[---]` → 去除并在其后追加分隔符（`appendSeparator=YES`）。
    - 二者同时出现 → 均去除并加分隔符。
  - 目录节点：item 中不含 `cmd`/`name` 的键视为文件夹键名（取值须为数组）。
  - 叶子节点：含 `cmd` 且 `name`。
- **SSH 主机注入**（在 JSON hosts 基础上合并，见 `loadMenu` 逻辑）：key 含 `/` 时按路径切分逐层建目录，末尾为叶子，`cmd = "ssh <key>"`。

## 5. SHTerminalCommand

- **字段**: `command`(NSString)、`theme`(NSString?)、`title`(NSString?)、`openMode`(enum: tab/new/current/virtual)、`fallbackName`(NSString)、`terminalType`(enum: terminal/iterm/ghostty)。
- **派发前归一化**（对应 openHost 现状逻辑）:
  1. theme 为 `(null)`/nil → 回退全局 `default_theme`；全局亦空 → iTerm 用 `Default`、其余用 `basic`。
  2. title 为 nil → 回退 `fallbackName`（菜单名）。
  3. openMode 为 nil → 回退全局 `open_in`；`open_in` 非 `tab`/`new` → 强制 `tab`。
  4. openMode 非法值（非四种）→ 抛错误并终止（与现状一致）。

## 6. SHTerminalBackend（协议）

- **协议方法**: `- (BOOL)dispatchCommand:(SHTerminalCommand *)command error:(NSError **)error;`
- **实现**:
  - `SHTerminalAppBackend` → 调 3 个 terminal-*.scpt（AppleScript，方法 runScript）。
  - `SHITermBackend` → 构造 `iterm2:/command?c=...` URL，`NSWorkspace openURL:`。
  - `SHGhosttyBackend` → `NSTask` 调 `ghostty +new-window|+new-tab -e <cmd>`。
  - `SHVirtualBackend` → `NSTask` 调 `screen -d -m -S <title> <cmd>`。
- **选择逻辑**: 由 `terminalType` + `openMode` 组合选择具体后端与参数（`virtual` 优先，其次按 terminal 类型）。

## 状态流转

```
应用启动 → SHConfigSource 解析路径/读取 JSON
         → 构建 SHShuttleConfig + (可选) SSH 主机字典
         → SHMenuBuilder 生成菜单树(SHMenuNode)
菜单打开(menuWillOpen:) → SHConfigSource.needUpdate?
         → 是: 重建；否: 复用
点击叶子 → SHTerminalCommand 归一化 → 选择 SHTerminalBackend → 派发
自启开关 → SHLaunchAtLogin (SMAppService.status 读 / register 写)
```

## 关键回归约束（SC-004）

- 菜单名称、层级、顺序、分隔符、命令必须与重构前逐项一致；`SHTerminalCommand` 的归一化顺序（theme→title→openMode）必须严格复刻 openHost 的判定分支顺序。