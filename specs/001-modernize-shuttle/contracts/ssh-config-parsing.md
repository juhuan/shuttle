# 契约：SSH Config 解析规则

> 本契约定义 `~/.ssh/config`、`/etc/ssh_config`、`/etc/ssh/ssh_config` 的解析与主机注入规则，FR-008/SC-004 要求与重构前完全一致。实现必须复刻 `parseSSHConfigFile` + `parseSSHConfig` + `loadMenu` 中注入逻辑的既有行为。

## 文件来源优先级

1. 系统级：优先 `/etc/ssh_config`；若仅存在 `/etc/ssh/ssh_config` 则用之。
2. 用户级：若 `~/.ssh/config` 存在，**覆盖**为最终解析文件（`configFile` 变量被重新赋值）。
3. 两者皆无 → 返回 nil，不注入任何主机。

## 逐行解析规则

- 正则：`^(#?)[ \t]*([^ \t=]+)[ \t=]+(.*)$`
  - 组1 = 可选 `#`（注释标记）；组2 = 键；组3 = 值。
  - 匹配不到 4 组 → 忽略该行。
- `Host` 键 → 开新段：值按空白切分为别名列表、过滤空串、取**首个**为 key，建立空字典 `servers[key]`。
- `Include` 键 → 递归解析：相对路径相对当前文件所在目录展开，结果 `addEntriesFromDictionary` 合并进 `servers`。
- 注释行且 key 已建立 且键前缀为 `shuttle.` → 写入 `servers[key][去掉 "shuttle." 前缀后的键名] = 值`（例如 `#shuttle.name foo` → `servers[当前key]["name"]="foo"`）。
- 其余注释行跳过。

## 主机注入菜单（在 `hosts` 基础上）

对 `servers` 每个 `(key, cfg)`：

1. 取显示名 `name = cfg["name"] ?: key`。
2. **忽略规则**（任一命中即跳过该主机）：
   - `name` 含 `*`（通配符）；
   - `name` 以 `.` 开头；
   - `name` 精确等于 `ssh_config_ignore_hosts` 任一值；
   - `name` 包含 `ssh_config_ignore_keywords` 任一子串。
3. **路径细分**：`name` 按 `/` 切分，末段为叶子名，前面各段为嵌套目录，逐级在 `hosts` 树中定位/创建（遇到已存在但非数组的同名项则终止该分支）。
4. 生成叶子：`cmd = "ssh <key>"`，`name = 叶子名`，追加到对应目录。
5. 仅当 `show_ssh_config_hosts` 不为显式 `false` 时才执行上述注入。

## 安全性约束（Edge Cases）

- 空文件 / 编码异常 → 安全返回（不崩溃）。
- 循环 `Include` → 解析能终止（不无限递归）。