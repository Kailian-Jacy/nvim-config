# 无视觉 AI 感知和调试 Neovim TUI 的方法研究报告

> 生成日期: 2026-03-06
> 环境: Ubuntu Linux, Neovim 0.11.6, tmux 3.4, Python 3.12.3 + pynvim 0.5.0
> 项目: nvim-config (LazyVim-based 配置)

---

## 目录

1. [研究背景](#1-研究背景)
2. [方案总览](#2-方案总览)
3. [方案详解与实验结果](#3-方案详解与实验结果)
   - [3.1 nvim --headless 模式](#31-nvim---headless-模式)
   - [3.2 nvim -l 脚本模式](#32-nvim--l-脚本模式)
   - [3.3 Neovim RPC/API (pynvim)](#33-neovim-rpcapi-pynvim)
   - [3.4 nvim --server 远程命令](#34-nvim---server-远程命令)
   - [3.5 tmux capture-pane](#35-tmux-capture-pane)
   - [3.6 tmux + RPC 组合方案](#36-tmux--rpc-组合方案)
   - [3.7 日志文件分析](#37-日志文件分析)
   - [3.8 tmux pipe-pane 终端输出录制](#38-tmux-pipe-pane-终端输出录制)
   - [3.9 Lua 语法检查](#39-lua-语法检查)
4. [方案对比矩阵](#4-方案对比矩阵)
5. [推荐最佳实践组合](#5-推荐最佳实践组合)
6. [对后续重构工作的建议](#6-对后续重构工作的建议)

---

## 1. 研究背景

我们是一个没有视觉/截图能力的 AI agent，运行在 Linux VM 上。需要对一个基于 LazyVim 的 Neovim 配置项目进行重构和调试。

**核心挑战**: Neovim 是终端 UI 程序，很多功能（语法高亮、补全弹窗、浮动窗口、状态栏、诊断标记等）依赖视觉反馈。我们需要找到不依赖"看屏幕"的方式来理解和验证 Neovim 的状态。

**项目特征**:
- 基于 LazyVim 框架
- 包含 ~20+ 插件配置文件 (`lua/plugins/*.lua`)
- 包含核心配置: options.lua, keymaps.lua, autocmds.lua, lazy.lua
- 有 init.lua 入口，引用 vimrc.vim 和 local config

---

## 2. 方案总览

| # | 方案 | 可行性 | 推荐度 |
|---|------|--------|--------|
| 1 | `nvim --headless` | ✅ 已验证 | ⭐⭐⭐⭐⭐ |
| 2 | `nvim -l` 脚本模式 | ✅ 已验证 | ⭐⭐⭐⭐⭐ |
| 3 | RPC/API (pynvim) | ✅ 已验证 | ⭐⭐⭐⭐⭐ |
| 4 | `nvim --server` | ✅ 已验证 | ⭐⭐⭐ |
| 5 | tmux capture-pane | ✅ 已验证 | ⭐⭐⭐⭐ |
| 6 | tmux + RPC 组合 | ✅ 已验证 | ⭐⭐⭐⭐⭐ |
| 7 | 日志文件分析 | ✅ 已验证 | ⭐⭐⭐ |
| 8 | tmux pipe-pane | ✅ 已验证 | ⭐⭐ |
| 9 | Lua 语法检查 | ✅ 已验证 | ⭐⭐⭐⭐ |

---

## 3. 方案详解与实验结果

### 3.1 nvim --headless 模式

**描述**: 以无 UI 模式启动 Neovim，通过 `-c` 参数执行 Vim/Lua 命令，输出到 stdout。

**适用场景**: 执行单次检查命令、批量处理、配置验证。

**优点**:
- 零依赖，nvim 自带
- 可以执行任何 Vim 命令和 Lua 代码
- 输出直接到 stdout，AI 可以直接读取
- 进程自动退出，不需要管理生命周期

**缺点**:
- 每次调用都要启动新的 nvim 实例
- 无法与用户配置的 UI 元素交互（没有 window、没有真实 terminal）
- 如果加载完整用户配置（含插件），启动慢且可能报错

**实验结果**:

```bash
# 执行简单 Lua 命令
$ nvim --headless -c 'lua print(vim.inspect(vim.version()))' -c 'qa!'
{
  api_compatible = 0,
  api_level = 13,
  major = 0,
  minor = 11,
  patch = 6,
}

# 读取文件内容
$ nvim --headless /path/to/file.lua \
  -c 'lua local lines = vim.api.nvim_buf_get_lines(0, 0, 10, false); for _, l in ipairs(lines) do print(l) end' \
  -c 'qa!'
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: ...

# 配置语法验证
$ nvim --headless -c 'luafile /path/to/config.lua' -c 'qa!' 2>&1
# (空输出 = 无错误, 有输出 = 有错误)
```

**结论**: ⭐⭐⭐⭐⭐ 最基础也最可靠的方案。适合一次性检查和验证。

---

### 3.2 nvim -l 脚本模式

**描述**: Neovim 0.9+ 支持 `nvim -l script.lua` 直接以 Lua 脚本模式运行，类似 `python script.py`。

**适用场景**: 复杂的批量检查、编写可复用的检查脚本。

**优点**:
- 最简洁的 API：像写普通 Lua 脚本一样
- 可以传递命令行参数 (`arg` table)
- 完整的 `vim.api` 可用
- 自动退出，不需要 `-c 'qa!'`

**缺点**:
- 需要 nvim 0.9+（本环境 0.11.6 支持）
- 不加载用户配置（除非显式 source）

**实验结果**:

```bash
$ cat > /tmp/inspect.lua << 'EOF'
print("Running via nvim -l")
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"Hello", "World"})
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
print("Buffer content: " .. vim.inspect(lines))
EOF

$ nvim -l /tmp/inspect.lua
Running via nvim -l
Buffer content: { "Hello", "World" }
```

**结论**: ⭐⭐⭐⭐⭐ 编写可复用检查脚本的最佳方式。推荐为常用检查封装成 `.lua` 脚本。

---

### 3.3 Neovim RPC/API (pynvim)

**描述**: 启动 nvim 并通过 Unix socket 或 TCP 暴露 RPC 接口，使用 Python 的 `pynvim` 库连接并调用所有 API。

**适用场景**: 需要持久交互、复杂状态查询、多步操作。

**优点**:
- 完整的 Neovim API 可用（buffer、window、option、keymap、treesitter...）
- 持久连接，可以多次查询而不重启 nvim
- Python 生态丰富，方便处理和分析结果
- 可以远程执行 Lua 代码 (`exec_lua`)
- 支持事件订阅

**缺点**:
- 需要额外依赖 (pynvim)
- 需要管理 nvim 进程的生命周期
- 部分 pynvim API 与 nvim 版本有兼容性问题（如 `nvim.options['tabstop']` 在某些版本不工作）
- `nvim.api.nvim_get_keymap` 在 pynvim 中变成了 `nvim_nvim_get_keymap`（方法名重复前缀 bug）

**实验结果**:

```python
import pynvim
nvim = pynvim.attach('socket', path='/tmp/nvim-rpc.sock')

# ✅ 读取 buffer 内容
nvim.current.buffer.name   # → "/path/to/options.lua"
nvim.current.buffer[:]     # → 全部行内容 (445 行)

# ✅ 读取选项 (用 eval 而非 options[])
nvim.eval('&tabstop')      # → 8
nvim.eval('&filetype')     # → "lua"

# ✅ 获取高亮组定义
nvim.command_output('hi Normal')  # → "Normal xxx guifg=..."

# ✅ 获取已加载脚本列表
nvim.command_output('scriptnames')  # → 24 个脚本

# ✅ 执行远程 Lua
nvim.exec_lua('return vim.treesitter.get_captures_at_pos(0, 0, 3)', [])
# → [{"capture": "comment", "lang": "lua", ...}]

# ✅ 获取窗口布局
nvim.exec_lua('return vim.inspect(vim.fn.winlayout())', [])
# → '{ "leaf", 1000 }'

# ✅ 获取 autocommand 列表
nvim.exec_lua('return vim.inspect(vim.api.nvim_get_autocmds({event = "BufReadPost"}))', [])

# ⚠️ 获取选项 - 需要用 eval 而不是 options
nvim.options['tabstop']  # → KeyError! 用 nvim.eval('&tabstop') 替代

# ⚠️ 获取 keymap - 方法名前缀问题
nvim.api.nvim_get_keymap('n')  # → Error: Invalid method: nvim_nvim_get_keymap
# 改用: nvim.command_output('nmap')
```

**重要发现 - 可查询的信息类型**:

| 信息类型 | API 方法 | 验证状态 |
|---------|---------|---------|
| Buffer 内容 | `nvim.current.buffer[:]` | ✅ |
| 文件名 | `nvim.current.buffer.name` | ✅ |
| 选项值 | `nvim.eval('&option')` | ✅ |
| 高亮组 | `nvim.command_output('hi GroupName')` | ✅ |
| Keymaps | `nvim.command_output('nmap')` | ✅ |
| 已加载脚本 | `nvim.command_output('scriptnames')` | ✅ |
| Treesitter 捕获 | `nvim.exec_lua(...)` | ✅ |
| 窗口布局 | `nvim.exec_lua('vim.fn.winlayout()')` | ✅ |
| 诊断信息 | `nvim.exec_lua('vim.diagnostic.get(0)')` | ✅ |
| Marks | `nvim.command_output('marks')` | ✅ |
| Autocommands | `nvim.exec_lua('nvim_get_autocmds')` | ✅ |
| 命名空间 | `nvim.exec_lua('nvim_get_namespaces')` | ✅ |
| 命令补全 | `nvim.eval('getcompletion(...)')` | ✅ |

**结论**: ⭐⭐⭐⭐⭐ 最强大的方案。适合需要深度、持续交互的场景。

---

### 3.4 nvim --server 远程命令

**描述**: 通过 `nvim --server <socket> --remote-expr <expr>` 向已运行的 nvim 实例发送命令。

**适用场景**: 快速一次性查询，不需要 Python。

**优点**:
- 纯命令行操作
- 不需要额外依赖

**缺点**:
- 功能有限，主要只支持 `--remote-expr` 和 `--remote-send`
- `--remote-send` 的输出不会返回到调用方
- 交互性较差

**实验结果**:

```bash
# 查询文件总行数
$ nvim --server /tmp/nvim.sock --remote-expr 'line("$")'
445

# 发送命令（但看不到输出）
$ nvim --server /tmp/nvim.sock --remote-send ':lua print(vim.api.nvim_buf_get_name(0))<CR>'
# 输出混合在一起: :lua print(...)path/to/file.lua
```

**结论**: ⭐⭐⭐ 可用但不如 pynvim 灵活。适合简单的一次性查询。

---

### 3.5 tmux capture-pane

**描述**: 在 tmux session 中运行 nvim，使用 `tmux capture-pane -p` 捕获终端的文本内容。

**适用场景**: 需要看到 nvim 的"可视化"输出——包括行号、状态栏、分屏边框等 UI 元素。

**优点**:
- 能看到 nvim 渲染后的"屏幕"文本
- 可以观察 UI 元素（行号、状态栏、分屏边框 `│`）
- 使用 `-e` 标志可以获取 ANSI 转义序列（颜色信息）
- 可以通过 `tmux send-keys` 模拟用户操作

**缺点**:
- 只能看到当前屏幕范围的内容
- 文本可能因换行被截断
- ANSI 转义序列解析复杂
- 分屏时文本拼接，需要解析列位置
- 无法获取 nvim 的内部状态（变量、选项等）

**实验结果**:

```bash
# 基础捕获
$ tmux capture-pane -t nvim-test -p | head -5
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: ...

# 开启行号后
$ tmux send-keys ':set number' Enter
$ tmux capture-pane -t nvim-test -p | head -3
  1 -- Options are automatically loaded before lazy.nvim startup
  2 -- Default options that are always set: ...

# 分屏后（可以观察到 │ 分隔符）
$ tmux send-keys ':vsplit' Enter
$ tmux capture-pane -t nvim-test -p | head -3
  1 -- Options are automatically loaded │  1 -- Options are automatically loaded
     before lazy.nvim startup           │     before lazy.nvim startup

# 底部状态栏
$ tmux capture-pane -t nvim-test -p | tail -2
<config/options.lua 1,1            Top <config/options.lua 1,1            Top
:vsplit

# 带颜色的捕获
$ tmux capture-pane -t nvim-test -p -e | head -3
# 包含 [96m, [39m, [0;1m 等 ANSI 转义序列，表示颜色
```

**结论**: ⭐⭐⭐⭐ 唯一能"看到"nvim 渲染后 UI 的方案。适合验证 UI 变化（分屏、弹窗、状态栏）。

---

### 3.6 tmux + RPC 组合方案

**描述**: 在 tmux 中运行 `nvim --listen <socket>`，同时使用 tmux capture-pane 看 UI 和 pynvim RPC 查询内部状态。

**适用场景**: 需要完整理解 nvim 当前状态的场景（UI + 内部状态）。

**优点**:
- 两全其美：UI 可见 + API 可查
- tmux 提供 UI 视角，RPC 提供数据视角
- 可以通过 RPC 操作 nvim，再通过 tmux 验证 UI 变化

**缺点**:
- 设置较复杂
- 需要管理 tmux session 和 nvim socket 两个资源

**实验结果**:

```bash
# 启动
tmux new-session -d -s nvim-combo -x 120 -y 40 \
  'nvim --listen /tmp/nvim-combo.sock /path/to/file.lua'

# RPC 查询
python3 -c "
import pynvim
nvim = pynvim.attach('socket', path='/tmp/nvim-combo.sock')
print(f'File: {nvim.current.buffer.name}')        # → path/to/theme.lua
print(f'Lines: {len(nvim.current.buffer[:])}')     # → 508
print(f'Filetype: {nvim.eval(\"&filetype\")}')     # → lua
"

# 同时获取 UI 视图
tmux capture-pane -t nvim-combo -p | head -5
# → return {
# →   {
# →     "Mofiqul/dracula.nvim",
# →     config = function()
# →       require("dracula").setup({
```

**结论**: ⭐⭐⭐⭐⭐ 最全面的方案。推荐作为日常调试的主要方式。

---

### 3.7 日志文件分析

**描述**: 通过 `-V{level}` 或 `-V{level}{file}` 启用详细日志，分析 nvim 的启动和执行过程。

**适用场景**: 调试启动问题、脚本加载顺序、错误追踪。

**优点**:
- 可以看到完整的脚本加载顺序
- 能发现隐式错误
- 持久化，可以事后分析

**缺点**:
- 日志量巨大（V5 级别）
- 需要从大量输出中过滤有用信息
- 不适合实时交互

**实验结果**:

```bash
# 标准 verbose 输出
$ nvim --headless -V2 -c 'qa!' 2>&1 | head -10
sourcing "nvim_exec2()"
finished sourcing nvim_exec2()
sourcing "/opt/nvim-linux-x86_64/share/nvim/runtime/ftplugin.vim"
...
could not source "/home/ubuntu/.config/nvim/init.vim"

# 日志文件
$ nvim --headless -V5/tmp/nvim-verbose.log -c 'qa!'
$ head -15 /tmp/nvim-verbose.log
# → 完整的脚本加载日志
```

**结论**: ⭐⭐⭐ 适合调试启动问题，不适合日常使用。

---

### 3.8 tmux pipe-pane 终端输出录制

**描述**: 使用 `tmux pipe-pane` 将终端的所有原始输出（含转义序列）记录到文件。

**适用场景**: 需要录制操作过程、事后分析。

**优点**:
- 捕获所有终端输出，包括颜色信息
- 类似 `script` 命令的功能

**缺点**:
- 输出包含大量 ANSI 转义序列，难以阅读
- 解析成本高
- 不适合实时使用

**实验结果**:

```bash
$ tmux pipe-pane -t nvim-dump -o 'cat >> /tmp/nvim-pane.log'
# 日志内容（cat -v 显示）:
# ^[[?25l^[[34B:set^[[Cnumber^[[2 q...
# ^[[H  1 -- Options are automatically loaded...
# ^[[96mfind_launch_json^[[m^O = ^[[0;1m^Ofunction^[[m^O...
```

**结论**: ⭐⭐ 仅在需要完整操作录制时使用。

---

### 3.9 Lua 语法检查

**描述**: 使用 `loadfile()` 或 `luac` 检查 Lua 文件的语法正确性。

**适用场景**: 修改配置文件后的快速验证。

**优点**:
- 极快（不需要启动完整 nvim）
- 可以批量检查
- 能精确定位语法错误位置

**缺点**:
- 只检查语法，不检查运行时错误
- 不了解 nvim 的 vim.* API 是否正确使用

**实验结果**:

```bash
# 通过 nvim 的 Lua 引擎检查
$ nvim --headless -c 'lua
  local files = vim.fn.glob("lua/plugins/*.lua", false, true)
  for _, f in ipairs(files) do
    local ok, err = loadfile(f)
    if not ok then print("ERROR: " .. f .. " -> " .. err) end
  end
' -c 'qa!'
# (空输出 = 全部通过)

# 通过 luac 检查
$ luac5.1 -p file.lua  # 只检查语法
```

**配置文件验证实验**:

```
autocmds.lua  → ⚠️ 运行时警告（yanky_ring 变量未设置，非致命）
keymaps.lua   → ❌ 运行时错误（modules 为 nil，第109行）
lazy.lua      → ⚠️ 无法独立运行（需要 plugins 目录上下文）
options.lua   → ✅ 通过
其他插件配置  → 大部分 ✅（依赖插件的几个有运行时错误，语法均正确）
```

**结论**: ⭐⭐⭐⭐ 修改后必做的第一步验证。

---

## 4. 方案对比矩阵

| 方案 | 设置难度 | 信息丰富度 | 实时性 | 可编程性 | 依赖 | 推荐场景 |
|------|---------|-----------|--------|---------|------|---------|
| `--headless` | ⭐ | ⭐⭐⭐⭐ | 一次性 | ⭐⭐⭐ | 无 | 单次检查、验证 |
| `nvim -l` | ⭐ | ⭐⭐⭐⭐ | 一次性 | ⭐⭐⭐⭐⭐ | 无 | 编写检查脚本 |
| pynvim RPC | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 持久 | ⭐⭐⭐⭐⭐ | pynvim | 深度调试、多步操作 |
| `--server` | ⭐⭐ | ⭐⭐ | 持久 | ⭐⭐ | 无 | 快速远程查询 |
| tmux capture | ⭐⭐ | ⭐⭐⭐ | 实时 | ⭐⭐⭐ | tmux | UI 状态验证 |
| tmux+RPC | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 实时 | ⭐⭐⭐⭐⭐ | tmux+pynvim | 完整调试 |
| 日志分析 | ⭐ | ⭐⭐⭐ | 事后 | ⭐ | 无 | 启动/加载问题 |
| pipe-pane | ⭐⭐ | ⭐⭐ | 录制 | ⭐ | tmux | 操作录制 |
| Lua 语法检查 | ⭐ | ⭐⭐ | 一次性 | ⭐⭐⭐ | 无 | 修改后快速验证 |

---

## 5. 推荐最佳实践组合

### 日常工作流（推荐）

```
修改配置文件
    ↓
[第1步] Lua 语法检查 (nvim -l 或 loadfile)
    ↓ 通过
[第2步] Headless 加载验证 (nvim --headless -c 'luafile ...')
    ↓ 通过
[第3步] RPC 状态检查 (pynvim 查询选项、keymap、highlight 等)
    ↓ 确认正确
[第4步] tmux capture-pane 视觉验证 (确认 UI 布局正确)
```

### 具体操作模式

#### 模式 A: 快速验证（修改单个文件后）

```bash
# 1. 语法检查
nvim --headless -c 'lua local ok,e = loadfile("file.lua"); print(ok and "OK" or e)' -c 'qa!'

# 2. 运行时检查
nvim --headless -c 'luafile file.lua' -c 'qa!' 2>&1
```

#### 模式 B: 深度调试（复杂问题）

```bash
# 1. 启动 tmux + nvim + RPC
tmux new-session -d -s debug -x 120 -y 40 \
  'nvim --listen /tmp/nvim-debug.sock -u /path/to/init.lua'

# 2. Python 脚本查询状态
python3 << 'EOF'
import pynvim
nvim = pynvim.attach('socket', path='/tmp/nvim-debug.sock')
# ... 查询各种状态
nvim.close()
EOF

# 3. tmux 验证 UI
tmux capture-pane -t debug -p
```

#### 模式 C: 批量检查（重构后全面验证）

```lua
-- check_all.lua (通过 nvim -l 运行)
local configs = vim.fn.glob("lua/plugins/*.lua", false, true)
local errors = {}
for _, f in ipairs(configs) do
  local ok, err = loadfile(f)
  if not ok then table.insert(errors, {file = f, error = err}) end
end
if #errors > 0 then
  print("ERRORS FOUND:")
  for _, e in ipairs(errors) do print("  " .. e.file .. ": " .. e.error) end
else
  print("All " .. #configs .. " files passed syntax check")
end
```

---

## 6. 对后续重构工作的建议

### 6.1 建立检查脚本库

在项目中创建 `scripts/` 目录，存放可复用的检查脚本：

```
nvim-config/
├── scripts/
│   ├── check-syntax.lua      # 批量语法检查
│   ├── check-keymaps.lua     # 检查 keymap 冲突
│   ├── check-options.lua     # 验证选项设置
│   ├── check-plugins.lua     # 检查插件加载状态
│   ├── check-highlights.lua  # 检查高亮组定义
│   └── inspect-config.lua    # 全面配置检查
```

### 6.2 使用 `nvim --headless` 进行配置加载测试

在每次修改后运行：

```bash
NVIM_APPNAME=config.nvim XDG_CONFIG_HOME=/path/to/nvim-config \
  nvim --headless -c 'lua print("Config loaded OK")' -c 'qa!' 2>&1
```

如果有报错，错误信息会包含文件路径和行号。

### 6.3 已发现的现有问题

在实验过程中发现以下问题，可作为重构的起点：

1. **keymaps.lua:109** - `attempt to index field 'modules' (a nil value)`
   - `keymaps.lua` 引用了 `modules` 字段但该字段为 nil
   - 可能是依赖了某个尚未加载的模块

2. **autocmds.lua** - `vim.g.yanky_ring_accept_length is not set`
   - 非致命警告，但说明配置之间有隐式依赖

3. **init.lua** - 引用 `vimrc.vim` 使用 `stdpath("config")` 
   - 当 `XDG_CONFIG_HOME` 不正确时找不到文件
   - 建议使用相对路径或更健壮的路径解析

### 6.4 重构时的验证清单

每次重构后，按顺序检查：

- [ ] 所有 `.lua` 文件通过语法检查 (`loadfile`)
- [ ] `init.lua` 能在 headless 模式下加载
- [ ] 核心选项正确设置（tabstop, shiftwidth, expandtab 等）
- [ ] Leader 键正确设置
- [ ] 插件数量与预期一致
- [ ] 关键 keymaps 存在且正确
- [ ] 无新增运行时错误/警告
- [ ] highlight 组定义正确（通过 RPC 查询）

### 6.5 不需要视觉验证的事项

大部分 Neovim 配置工作实际上**不需要视觉反馈**：

- ✅ 选项设置 → `nvim.eval('&option')`
- ✅ Keymap 定义 → `command_output('nmap')`
- ✅ 插件加载状态 → `exec_lua('require("lazy.core.config").plugins')`
- ✅ 自动命令 → `exec_lua('nvim_get_autocmds')`
- ✅ Treesitter 语法树 → `exec_lua('vim.treesitter.get_captures_at_pos')`
- ✅ 诊断信息 → `exec_lua('vim.diagnostic.get')`
- ✅ 高亮组颜色值 → `nvim_get_hl(0, {name = "..."})`

### 6.6 必须使用 tmux capture-pane 验证的事项

少数场景确实需要"看到"渲染结果：

- 🔍 状态栏布局和内容
- 🔍 浮动窗口的位置和大小
- 🔍 分屏布局
- 🔍 缩进指南线的显示
- 🔍 Git diff 标记的位置
- 🔍 补全弹窗的内容

---

## 附录: 环境信息

```
OS:       Ubuntu Linux 6.8.0-71-generic (x64)
Neovim:   v0.11.6 (实际), v0.9.5 (apt 包)
tmux:     3.4
Python:   3.12.3
pynvim:   0.5.0
项目:     LazyVim-based, ~20 插件配置
```

> **注**: 系统中存在两个 nvim 版本。`/usr/bin/nvim` (0.9.5, apt 安装) 和 `/opt/nvim-linux-x86_64/` 中的 0.11.6。实际执行时使用的是 0.11.6 版本（通过 PATH 优先级或符号链接）。
