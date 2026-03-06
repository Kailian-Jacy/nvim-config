# Test Plan Part 1: Options & Global Settings

> 测试方法: `nvim --headless -u config.nvim/init.lua +"luafile test_script.lua" +qa`
> 或通过 pynvim RPC 连接进行 API 查询

---

## 1.1 init.lua — 启动加载顺序

### TC-INIT-001: vimrc.vim 被加载
- **前置条件**: 无
- **测试步骤**: 启动 nvim，查询 vimrc.vim 中设置的选项
- **验证**: `vim.api.nvim_exec2("set incsearch?", {output=true})` 返回 `incsearch`
- **验证方式**: API 查询

### TC-INIT-002: options.lua 被加载
- **前置条件**: 无
- **测试步骤**: 启动 nvim，查询 options.lua 中设置的 `mapleader`
- **验证**: `vim.g.mapleader == " "`
- **验证方式**: API 查询

### TC-INIT-003: keymaps.lua 被加载
- **前置条件**: 无
- **测试步骤**: 启动 nvim，查询 keymaps.lua 中设定的 keymap（如 `*` 键的 remap）
- **验证**: `vim.fn.maparg("*", "n")` 非空
- **验证方式**: API 查询

### TC-INIT-004: autocmds.lua 被加载
- **前置条件**: 无
- **测试步骤**: 启动 nvim，查询自定义命令 `RunScript` 是否存在
- **验证**: `vim.fn.exists(":RunScript") == 2`
- **验证方式**: API 查询

### TC-INIT-005: lazy.nvim 插件管理器被加载
- **前置条件**: 无
- **测试步骤**: 启动 nvim，检查 lazy.nvim 是否可用
- **验证**: `require("lazy") ~= nil`（不抛错）
- **验证方式**: API 查询

### TC-INIT-006: local.lua hook 机制 — before_all
- **前置条件**: 创建 `config/local.lua`，在 `before_all` 中设置 `vim.g._test_before_all = true`
- **测试步骤**: 启动 nvim
- **验证**: `vim.g._test_before_all == true`
- **验证方式**: API 查询

### TC-INIT-007: local.lua hook 机制 — after_options
- **前置条件**: 创建 `config/local.lua`，在 `after_options` 中设置 `vim.g._test_after_options = true`
- **测试步骤**: 启动 nvim
- **验证**: `vim.g._test_after_options == true`
- **验证方式**: API 查询

### TC-INIT-008: local.lua hook 机制 — after_all
- **前置条件**: 同上，设置 `after_all` hook
- **测试步骤**: 启动 nvim
- **验证**: `vim.g._test_after_all == true`
- **验证方式**: API 查询

### TC-INIT-009: local.lua 不存在时正常启动
- **前置条件**: 确保 `config/local.lua` 不存在
- **测试步骤**: 启动 nvim
- **验证**: nvim 正常启动，无错误
- **验证方式**: API 查询退出码

---

## 1.2 vimrc.vim — Vim 选项

### TC-VIM-001: filetype plugin indent on
- **验证**: `vim.bo.filetype` 在打开 `.py` 文件时为 `"python"`
- **验证方式**: 打开 python 文件后 API 查询

### TC-VIM-002: incsearch 开启
- **验证**: `vim.o.incsearch == true`
- **验证方式**: API 查询

### TC-VIM-003: ignorecase 开启
- **验证**: `vim.o.ignorecase == true`
- **验证方式**: API 查询

### TC-VIM-004: smartcase 开启
- **验证**: `vim.o.smartcase == true`
- **验证方式**: API 查询

### TC-VIM-005: hlsearch 开启
- **验证**: `vim.o.hlsearch == true`
- **验证方式**: API 查询

### TC-VIM-006: wildmode 设置
- **验证**: `vim.o.wildmode == "longest,list,full"`
- **验证方式**: API 查询

### TC-VIM-007: showbreak 设置
- **验证**: `vim.o.showbreak == "↪\\"`（包含反斜杠）
- **验证方式**: API 查询

### TC-VIM-008: list 和 listchars 设置
- **验证**: `vim.o.list == true` 且 `vim.o.listchars` 包含 `tab:→`
- **验证方式**: API 查询

### TC-VIM-009: wrap 开启
- **验证**: `vim.o.wrap == true`
- **验证方式**: API 查询

### TC-VIM-010: breakindent 开启
- **验证**: `vim.o.breakindent == true`
- **验证方式**: API 查询

### TC-VIM-011: textwidth = 0
- **验证**: `vim.o.textwidth == 0`
- **验证方式**: API 查询

### TC-VIM-012: hidden 开启
- **验证**: `vim.o.hidden == true`
- **验证方式**: API 查询

### TC-VIM-013: title 开启
- **验证**: `vim.o.title == true`
- **验证方式**: API 查询

### TC-VIM-014: linebreak 开启
- **验证**: `vim.o.linebreak == true`
- **验证方式**: API 查询

### TC-VIM-015: smoothscroll 开启
- **验证**: `vim.o.smoothscroll == true`
- **验证方式**: API 查询

### TC-VIM-016: termguicolors 开启
- **验证**: `vim.o.termguicolors == true`
- **验证方式**: API 查询

### TC-VIM-017: softtabstop=4 (vimrc)
- **验证**: `vim.o.softtabstop == 4`（注意 options.lua 后来可能覆写为 2）
- **验证方式**: API 查询，需确认最终生效值

### TC-VIM-018: smarttab 开启
- **验证**: `vim.o.smarttab == true`
- **验证方式**: API 查询

### TC-VIM-019: autoindent 开启
- **验证**: `vim.o.autoindent == true`
- **验证方式**: API 查询

### TC-VIM-020: j/k 映射使用 gj/gk（count=0 时）
- **前置条件**: 打开有长行 wrap 的文件
- **验证**: `vim.fn.maparg("j", "n")` 包含 `gj` 或为表达式映射
- **验证方式**: API 查询

### TC-VIM-021: QFdelete 函数存在
- **验证**: `vim.fn.exists("*QFdelete") == 1`
- **验证方式**: API 查询

### TC-VIM-022: quickfix buffer dd 映射
- **前置条件**: 打开 quickfix 列表（`:copen`）
- **验证**: 在 quickfix buffer 中 `dd` 映射到 QFdelete
- **验证方式**: `vim.fn.maparg("dd", "n", false, true)` 在 quickfix buffer 中检查

### TC-VIM-023: CursorLineNr 高亮为 bold
- **验证**: 检查 `CursorLineNr` highlight group 包含 `bold`
- **验证方式**: `vim.api.nvim_get_hl(0, {name="CursorLineNr"})` 检查 bold 属性

### TC-VIM-024: FileType html — shiftwidth=2
- **前置条件**: 打开 .html 文件
- **验证**: `vim.bo.shiftwidth == 2`
- **验证方式**: API 查询

### TC-VIM-025: FileType css — shiftwidth=2
- **前置条件**: 打开 .css 文件
- **验证**: `vim.bo.shiftwidth == 2`
- **验证方式**: API 查询

### TC-VIM-026: FileType xml — shiftwidth=2
- **前置条件**: 打开 .xml 文件
- **验证**: `vim.bo.shiftwidth == 2`
- **验证方式**: API 查询

### TC-VIM-027: FileType json — shiftwidth=2
- **前置条件**: 打开 .json 文件
- **验证**: `vim.bo.shiftwidth == 2`
- **验证方式**: API 查询

### TC-VIM-028: FileType journal — shiftwidth=2
- **前置条件**: `set filetype=journal`
- **验证**: `vim.bo.shiftwidth == 2`
- **验证方式**: API 查询

### TC-VIM-029: Telescope diagnostics 映射 (vimrc)
- **验证**: `vim.fn.maparg("<leader>le", "n")` 包含 `Telescope diagnostics`
- **验证方式**: API 查询

### TC-VIM-030: Telescope dap commands 映射 (vimrc)
- **验证**: `vim.fn.maparg("<leader>sd", "n")` 包含 `Telescope dap`（注意可能被后续覆盖）
- **验证方式**: API 查询

---

## 1.3 options.lua — Lua 全局选项

### TC-OPT-001: mapleader = " "
- **验证**: `vim.g.mapleader == " "`
- **验证方式**: API 查询

### TC-OPT-002: maplocalleader = "\\"
- **验证**: `vim.g.maplocalleader == "\\"`
- **验证方式**: API 查询

### TC-OPT-003: laststatus=3 (全局状态栏)
- **验证**: `vim.o.laststatus == 3`
- **验证方式**: API 查询

### TC-OPT-004: signcolumn=yes:1
- **验证**: `vim.o.signcolumn == "yes:1"`
- **验证方式**: API 查询

### TC-OPT-005: cmdheight=0
- **验证**: `vim.o.cmdheight == 0`
- **验证方式**: API 查询

### TC-OPT-006: noshowmode
- **验证**: `vim.o.showmode == false`
- **验证方式**: API 查询

### TC-OPT-007: noruler
- **验证**: `vim.o.ruler == false`
- **验证方式**: API 查询

### TC-OPT-008: noshowcmd
- **验证**: `vim.o.showcmd == false`
- **验证方式**: API 查询

### TC-OPT-009: syntax off
- **验证**: `vim.api.nvim_exec2("syntax", {output=true}).output` 包含 "off"
- **验证方式**: API 查询

### TC-OPT-010: undofile 开启
- **验证**: `vim.o.undofile == true`
- **验证方式**: API 查询

### TC-OPT-011: number 开启
- **验证**: `vim.o.number == true`
- **验证方式**: API 查询

### TC-OPT-012: relativenumber 开启
- **验证**: `vim.o.relativenumber == true`
- **验证方式**: API 查询

### TC-OPT-013: cursorline 开启
- **验证**: `vim.o.cursorline == true`
- **验证方式**: API 查询

### TC-OPT-014: autoread 开启
- **验证**: `vim.o.autoread == true`
- **验证方式**: API 查询

### TC-OPT-015: tabstop=2
- **验证**: `vim.o.tabstop == 2`
- **验证方式**: API 查询

### TC-OPT-016: softtabstop=2 (覆写 vimrc 的 4)
- **验证**: `vim.o.softtabstop == 2`
- **验证方式**: API 查询

### TC-OPT-017: shiftwidth=0 (跟随 tabstop)
- **验证**: `vim.o.shiftwidth == 0`
- **验证方式**: API 查询

### TC-OPT-018: expandtab 开启
- **验证**: `vim.o.expandtab == true`
- **验证方式**: API 查询

### TC-OPT-019: autoformat 关闭
- **验证**: `vim.g.autoformat == false`
- **验证方式**: API 查询

### TC-OPT-020: fillchars 包含 diff 和 eob 设置
- **验证**: `vim.o.fillchars` 包含 `"diff:╱"` 和 `"eob:~"`
- **验证方式**: API 查询

### TC-OPT-021: copilot_filetypes — markdown 禁用
- **验证**: `vim.g.copilot_filetypes.markdown == false`
- **验证方式**: API 查询

### TC-OPT-022: copilot_filetypes — yaml 禁用
- **验证**: `vim.g.copilot_filetypes.yaml == false`
- **验证方式**: API 查询

### TC-OPT-023: copilot_filetypes — toml 禁用
- **验证**: `vim.g.copilot_filetypes.toml == false`
- **验证方式**: API 查询

---

## 1.4 options.lua — 全局变量和辅助函数

### TC-OPT-024: vim.g.read_binary_with_xxd 默认 false
- **验证**: `vim.g.read_binary_with_xxd == false`
- **验证方式**: API 查询

### TC-OPT-025: vim.g._resource_cpu_cores 为正整数
- **验证**: `type(vim.g._resource_cpu_cores) == "number" and vim.g._resource_cpu_cores >= 1`
- **验证方式**: API 查询

### TC-OPT-026: vim.g._env_os_type 为有效值
- **验证**: `vim.tbl_contains({"MACOS", "LINUX", "WINDOWS", "UNKNOWN"}, vim.g._env_os_type)`
- **验证方式**: API 查询

### TC-OPT-027: vim.g._resource_executable_sqlite 检测
- **验证**: `vim.g._resource_executable_sqlite` 与 `vim.fn.executable("sqlite3")` 一致
- **验证方式**: API 查询

### TC-OPT-028: modules.rust 依据 rustc 可执行性
- **验证**: `vim.g.modules.rust.enabled == (vim.fn.executable("rustc") == 1)`
- **验证方式**: API 查询

### TC-OPT-029: modules.go 依据 go 可执行性
- **验证**: `vim.g.modules.go.enabled == (vim.fn.executable("go") == 1)`
- **验证方式**: API 查询

### TC-OPT-030: modules.python 依据 python 可执行性
- **验证**: `vim.g.modules.python.enabled == (vim.fn.executable("python") == 1 or vim.fn.executable("python3") == 1)`
- **验证方式**: API 查询

### TC-OPT-031: modules.cpp 依据 gcc 可执行性
- **验证**: `vim.g.modules.cpp.enabled == (vim.fn.executable("gcc") == 1)`
- **验证方式**: API 查询

### TC-OPT-032: modules.copilot 依据 node 可执行性
- **验证**: `vim.g.modules.copilot.enabled == (vim.fn.executable("node") == 1)`
- **验证方式**: API 查询

### TC-OPT-033: modules.svn 依据 svn 可执行性
- **验证**: `vim.g.modules.svn.enabled == (vim.fn.executable("svn") == 1)`
- **验证方式**: API 查询

### TC-OPT-034: modules 可被 local.lua 覆写
- **前置条件**: 在 `local.lua` 的 `before_all` 中设置 `vim.g.modules = { rust = { enabled = false } }`
- **验证**: `vim.g.modules.rust.enabled == false`（即使 rustc 存在）
- **验证方式**: API 查询

### TC-OPT-035: vim.g.find_launch_json 函数存在且可调用
- **前置条件**: 创建 `/tmp/test/.vscode/launch.json`
- **测试步骤**: `vim.g.find_launch_json("/tmp/test")`
- **验证**: 返回 `"/tmp/test/.vscode/launch.json"` 和对应目录
- **验证方式**: API 查询

### TC-OPT-036: vim.g.find_launch_json 不存在时返回 nil
- **前置条件**: 确保 `/tmp/test_empty/` 无 `.vscode/launch.json`
- **验证**: 返回 `nil, nil`
- **验证方式**: API 查询

### TC-OPT-037: vim.g.is_current_window_floating 非浮动时返回 false
- **前置条件**: 普通窗口中调用
- **验证**: `vim.g.is_current_window_floating() == false`
- **验证方式**: API 查询

### TC-OPT-038: vim.g.is_plugin_loaded 查询已加载插件
- **验证**: 对已安装插件返回 truthy
- **验证方式**: API 查询

### TC-OPT-039: vim.g.get_full_path_of 已存在的可执行文件
- **验证**: `vim.g.get_full_path_of("ls")` 返回非空路径
- **验证方式**: API 查询

### TC-OPT-040: vim.g.get_full_path_of 不存在的可执行文件
- **验证**: `vim.g.get_full_path_of("nonexistent_binary_xyz")` 返回 `""`
- **验证方式**: API 查询

---

## 1.5 options.lua — Terminal 相关全局变量

### TC-OPT-041: terminal_width_right 默认 0.3
- **验证**: `vim.g.terminal_width_right == 0.3`
- **验证方式**: API 查询

### TC-OPT-042: terminal_width_left 默认 0.3
- **验证**: `vim.g.terminal_width_left == 0.3`
- **验证方式**: API 查询

### TC-OPT-043: terminal_width_bottom 默认 0.3
- **验证**: `vim.g.terminal_width_bottom == 0.3`
- **验证方式**: API 查询

### TC-OPT-044: terminal_width_top 默认 0.3
- **验证**: `vim.g.terminal_width_top == 0.3`
- **验证方式**: API 查询

### TC-OPT-045: terminal_auto_insert 默认 true
- **验证**: `vim.g.terminal_auto_insert == true`
- **验证方式**: API 查询

### TC-OPT-046: terminal_default_tmux_session_name 默认 "nvim-attached"
- **验证**: `vim.g.terminal_default_tmux_session_name == "nvim-attached"`
- **验证方式**: API 查询

---

## 1.6 options.lua — Tabline 相关

### TC-OPT-047: vim.go.tabline 被设置为 Lua 函数
- **验证**: `vim.go.tabline == "%!v:lua.Tabline()"`
- **验证方式**: API 查询

### TC-OPT-048: Tabline() 函数返回字符串
- **验证**: `type(Tabline()) == "string"`
- **验证方式**: API 查询

### TC-OPT-049: vim.g.tabname 返回工作目录名
- **前置条件**: 当前 tab 无自定义名
- **验证**: `vim.g.tabname(1)` 返回 `vim.fn.fnamemodify(vim.fn.getcwd(), ":t")`
- **验证方式**: API 查询

### TC-OPT-050: vim.g.tabname 自定义名优先
- **前置条件**: `vim.fn.settabvar(1, "tabname", "MyTab")`
- **验证**: `vim.g.tabname(1) == "MyTab"`
- **验证方式**: API 查询

### TC-OPT-051: vim.g.tabname 路径匹配标记
- **前置条件**: 设置 `vim.g.tab_path_mark = { ["test"] = "T" }`，当前工作目录包含 "test"
- **验证**: `vim.g.tabname(1)` 包含 `"[T]"`
- **验证方式**: API 查询

### TC-OPT-052: vim.g.pinned_tab 初始为 nil
- **验证**: `vim.g.pinned_tab == nil` 或 `vim.NIL`
- **验证方式**: API 查询

### TC-OPT-053: vim.g.pinned_tab_marker 为图标
- **验证**: `vim.g.pinned_tab_marker == "󰐃"`
- **验证方式**: API 查询

---

## 1.7 options.lua — 辅助函数

### TC-OPT-054: function_get_selected_content 视觉模式获取内容
- **前置条件**: 插入 "hello world"，视觉选中 "hello"
- **验证**: `vim.g.function_get_selected_content()` 返回 `"hello"`
- **验证方式**: API 查询（需模拟视觉选择）

### TC-OPT-055: is_in_visual_mode 在 normal 模式返回 false
- **验证**: `vim.g.is_in_visual_mode() == false`
- **验证方式**: API 查询

### TC-OPT-056: get_word_under_cursor 返回光标下单词
- **前置条件**: 插入 "hello world"，光标在 "hello" 上
- **验证**: `vim.g.get_word_under_cursor() == "hello"`
- **验证方式**: API 查询

---

## 1.8 options.lua — Neovide 设置

### TC-OPT-057: neovide_show_border = true
- **验证**: `vim.g.neovide_show_border == true`
- **验证方式**: API 查询

### TC-OPT-058: neovide_input_macos_option_key_is_meta = 'only_left'
- **验证**: `vim.g.neovide_input_macos_option_key_is_meta == 'only_left'`
- **验证方式**: API 查询

### TC-OPT-059: neovide_scroll_animation_length
- **验证**: `vim.g.neovide_scroll_animation_length == 0.13`
- **验证方式**: API 查询

### TC-OPT-060: neovide_opacity 接近 1
- **验证**: `vim.g.neovide_opacity == 0.99`
- **验证方式**: API 查询

### TC-OPT-061: neovide_normal_opacity = 0.3
- **验证**: `vim.g.neovide_normal_opacity == 0.3`
- **验证方式**: API 查询

### TC-OPT-062: neovide padding 设置
- **验证**: `vim.g.neovide_padding_top == 10 and vim.g.neovide_padding_right == 10 and vim.g.neovide_padding_bottom == 10`
- **验证方式**: API 查询

### TC-OPT-063: neovide_window_blurred = true
- **验证**: `vim.g.neovide_window_blurred == true`
- **验证方式**: API 查询

### TC-OPT-064: neovide floating blur 设置
- **验证**: `vim.g.neovide_floating_blur_amount_x == 5 and vim.g.neovide_floating_blur_amount_y == 5`
- **验证方式**: API 查询

---

## 1.9 options.lua — 格式化和调试相关

### TC-OPT-065: format_behavior.default = "restrict"
- **验证**: `vim.g.format_behavior.default == "restrict"`
- **验证方式**: API 查询

### TC-OPT-066: format_behavior.rust = "all"
- **验证**: `vim.g.format_behavior.rust == "all"`
- **验证方式**: API 查询

### TC-OPT-067: max_silent_format_line_cnt = 10
- **验证**: `vim.g.max_silent_format_line_cnt == 10`
- **验证方式**: API 查询

### TC-OPT-068: debugging_status 默认 "NoDebug"
- **验证**: `vim.g.debugging_status == "NoDebug"`
- **验证方式**: API 查询

### TC-OPT-069: recording_status 默认 false
- **验证**: `vim.g.recording_status == false`
- **验证方式**: API 查询

### TC-OPT-070: debugging_keymap 默认 false
- **验证**: `vim.g.debugging_keymap == false`
- **验证方式**: API 查询

### TC-OPT-071: debug_virtual_text_truncate_size = 20
- **验证**: `vim.g.debug_virtual_text_truncate_size == 20`
- **验证方式**: API 查询

---

## 1.10 options.lua — Snippet 和 Yanky 设置

### TC-OPT-072: import_user_snippets = true
- **验证**: `vim.g.import_user_snippets == true`
- **验证方式**: API 查询

### TC-OPT-073: user_vscode_snippets_path 包含 config/snip/
- **验证**: `vim.g.user_vscode_snippets_path[1]` 以 `/snip/` 结尾
- **验证方式**: API 查询

### TC-OPT-074: yanky_ring_accept_length = 10
- **验证**: `vim.g.yanky_ring_accept_length == 10`
- **验证方式**: API 查询

### TC-OPT-075: yanky_ring_max_accept_length = 1000
- **验证**: `vim.g.yanky_ring_max_accept_length == 1000`
- **验证方式**: API 查询

---

## 1.11 options.lua — 其他设置

### TC-OPT-076: scroll_bar_hide = true
- **验证**: `vim.g.scroll_bar_hide == true`
- **验证方式**: API 查询

### TC-OPT-077: indent_blankline_hide = true
- **验证**: `vim.g.indent_blankline_hide == true`
- **验证方式**: API 查询

### TC-OPT-078: LAST_WORKING_DIRECTORY 默认 "~"
- **验证**: `vim.g.LAST_WORKING_DIRECTORY == "~"`
- **验证方式**: API 查询

### TC-OPT-079: copilot_no_maps = true (keymaps.lua)
- **验证**: `vim.g.copilot_no_maps == true`
- **验证方式**: API 查询

### TC-OPT-080: TablineString 函数存在
- **验证**: `type(TablineString) == "function"`
- **验证方式**: API 查询

---

**本模块测试用例总数: 80**
