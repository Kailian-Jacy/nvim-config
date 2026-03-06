# Test Plan Part 4: Plugin Configurations & Integration

> 测试方法: 验证插件加载、配置选项、暴露的键映射和命令

---

## 4.1 Terminal.nvim (editor.lua)

### TC-PLG-001: terminal.nvim 插件加载
- **验证**: `require("terminal")` 不报错
- **验证方式**: API 查询

### TC-PLG-002: `<leader>tt` 切换浮动终端
- **验证**: `vim.fn.maparg("<leader>tt", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-003: `<leader>gg` 打开 lazygit
- **验证**: `vim.fn.maparg("<leader>gg", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-004: Lazygit 命令存在
- **验证**: `vim.fn.exists(":Lazygit") == 2`
- **验证方式**: API 查询

### TC-PLG-005: `<c-bs>` 在 terminal 模式重置终端位置
- **验证**: `vim.fn.maparg("<c-bs>", "t")` 非空
- **验证方式**: API 查询

### TC-PLG-006: `<c-s-l>` 在 terminal 模式移到右侧
- **验证**: `vim.fn.maparg("<c-s-l>", "t")` 非空
- **验证方式**: API 查询

### TC-PLG-007: `<d-esc>` 在 terminal 模式退出到 normal
- **验证**: `vim.fn.maparg("<d-esc>", "t")` 包含 `<C-\\><C-N>`
- **验证方式**: API 查询

### TC-PLG-008: `<c-esc>` 在 terminal 模式退出到 normal
- **验证**: `vim.fn.maparg("<c-esc>", "t")` 包含 `<C-\\><C-N>`
- **验证方式**: API 查询

### TC-PLG-009: TermOpen autocmd 设置 buflisted=false
- **前置条件**: 打开终端 buffer
- **验证**: `vim.bo.buflisted == false` 对终端 buffer
- **验证方式**: API 查询

### TC-PLG-010: terminal_auto_insert 打开终端自动进 insert
- **前置条件**: `vim.g.terminal_auto_insert == true`
- **验证**: WinEnter 终端 buffer 时自动进入 insert 模式
- **验证方式**: API 查询模式

---

## 4.2 local-highlight.nvim (editor.lua)

### TC-PLG-011: local-highlight 插件加载
- **验证**: `require("local-highlight")` 不报错
- **验证方式**: API 查询

### TC-PLG-012: hlgroup 设置为 FaintSelected
- **验证**: 插件配置中 hlgroup == "FaintSelected"
- **验证方式**: 检查 highlight group 存在

---

## 4.3 bufjump.nvim (editor.lua)

### TC-PLG-013: `H` 跳到上一个 buffer
- **验证**: `vim.fn.maparg("H", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-014: `L` 跳到下一个 buffer
- **验证**: `vim.fn.maparg("L", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-015: H 跳过终端 buffer
- **前置条件**: buffer 历史中有终端 buffer
- **验证**: 跳转时会额外跳一次跳过 term://
- **验证方式**: 功能测试

---

## 4.4 LuaSnip (editor.lua)

### TC-PLG-016: LuaSnip 加载
- **验证**: `require("luasnip")` 不报错
- **验证方式**: API 查询

### TC-PLG-017: 用户代码片段路径配置
- **验证**: 若 `vim.g.import_user_snippets`，从 `vim.g.user_vscode_snippets_path` 加载
- **验证方式**: 检查 luasnip 是否有加载的 snippets

---

## 4.5 visual-surround.nvim (editor.lua)

### TC-PLG-018: visual-surround 加载
- **验证**: `require("visual-surround")` 不报错
- **验证方式**: API 查询

### TC-PLG-019: `<` 在 visual mode 包裹选择
- **验证**: `vim.fn.maparg("<", "x")` 非空（expr 映射）
- **验证方式**: API 查询

### TC-PLG-020: `<` 在 visual-line mode 保持默认缩进行为
- **验证**: V 模式下 `<` 仍为缩进
- **验证方式**: 功能测试

---

## 4.6 auto-indent.nvim (editor.lua)

### TC-PLG-021: auto-indent 加载
- **验证**: `vim.g._auto_indent_used == true`
- **验证方式**: API 查询

---

## 4.7 todo-comments.nvim (editor.lua)

### TC-PLG-022: `<leader>mt` 添加 TODO 标记
- **验证**: `vim.fn.maparg("<leader>mt", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-023: todo-comments signs 禁用
- **验证**: 配置中 `signs = false`
- **验证方式**: 检查配置

### TC-PLG-024: CHECK 和 BUGREPORT 关键字配置
- **验证**: todo-comments 识别 CHECK 和 BUGREPORT
- **验证方式**: 功能测试（在 buffer 写入 `-- CHECK:` 查看高亮）

---

## 4.8 bookmarks.nvim (editor.lua)

### TC-PLG-025: `'` 打开 bookmark picker
- **验证**: `vim.fn.maparg("'", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-026: `m` 创建/切换书签
- **验证**: `vim.fn.maparg("m", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-027: `M` 打开书签描述
- **验证**: `vim.fn.maparg("M", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-028: `<leader>mm` 在标记文件中 grep
- **验证**: `vim.fn.maparg("<leader>mm", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-029: `<leader>md` 删除光标处书签
- **验证**: `vim.fn.maparg("<leader>md", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-030: `gm` 显示书签信息
- **验证**: `vim.fn.maparg("gm", "n")` 非空
- **验证方式**: API 查询

---

## 4.9 Mason (lsp.lua)

### TC-PLG-031: mason.nvim 加载
- **验证**: `require("mason")` 不报错
- **验证方式**: API 查询

### TC-PLG-032: mason.ensure_installed 表存在
- **验证**: `require("mason").ensure_installed` 非 nil，包含多个语言类别
- **验证方式**: API 查询

### TC-PLG-033: mason.is_installed 函数可调用
- **验证**: `type(require("mason").is_installed) == "function"`
- **验证方式**: API 查询

### TC-PLG-034: mason.link_as_install 函数可调用
- **验证**: `type(require("mason").link_as_install) == "function"`
- **验证方式**: API 查询

### TC-PLG-035: mason.try_link_before_install 函数可调用
- **验证**: `type(require("mason").try_link_before_install) == "function"`
- **验证方式**: API 查询

---

## 4.10 Treesitter textobjects (lsp.lua)

### TC-PLG-036: `af` textobject 选择函数外部
- **验证**: treesitter textobjects 配置包含 `af = "@function.outer"`
- **验证方式**: 功能测试

### TC-PLG-037: `if` textobject 选择函数内部
- **验证**: treesitter textobjects 配置包含 `if = "@function.inner"`
- **验证方式**: 功能测试

### TC-PLG-038: `ac` textobject 选择类外部
- **验证**: 配置包含 `ac = "@class.outer"`
- **验证方式**: 功能测试

### TC-PLG-039: `ic` textobject 选择类内部
- **验证**: 配置包含 `ic = "@class.inner"`
- **验证方式**: 功能测试

### TC-PLG-040: `<Tab>` 增量选择初始化
- **验证**: incremental_selection keymaps 配置 `init_selection = '<Tab>'`
- **验证方式**: 功能测试

### TC-PLG-041: `<S-Tab>` 增量选择缩小
- **验证**: `node_decremental = '<S-TAB>'`
- **验证方式**: 功能测试

---

## 4.11 nvim-lspconfig (lsp.lua)

### TC-PLG-042: lua_ls 配置存在
- **验证**: lspconfig.lua_ls 已 setup
- **验证方式**: `:LspInfo` 在 lua 文件中显示 lua_ls

### TC-PLG-043: lua_ls 识别 vim 和 Snacks 全局
- **验证**: Lua 诊断中不报告 `vim` 和 `Snacks` 为未定义全局
- **验证方式**: 功能测试

### TC-PLG-044: jsonls snippetSupport 启用
- **验证**: jsonls 配置中 capabilities 包含 snippetSupport
- **验证方式**: 配置检查

### TC-PLG-045: pyright 配置
- **验证**: lspconfig.pyright 已 setup
- **验证方式**: `:LspInfo` 在 python 文件中检查

### TC-PLG-046: LSP inlay hint 启用
- **验证**: `vim.lsp.inlay_hint.is_enabled() == true`
- **验证方式**: API 查询

### TC-PLG-047: clangd 配置（cpp 模块启用时）
- **前置条件**: `vim.g.modules.cpp.enabled == true`
- **验证**: clangd 已 setup
- **验证方式**: 配置检查

### TC-PLG-048: gopls 配置（go 模块启用时）
- **前置条件**: `vim.g.modules.go.enabled == true`
- **验证**: gopls 已 setup
- **验证方式**: 配置检查

---

## 4.12 nvim-lint (lsp.lua)

### TC-PLG-049: lint linters_by_ft 配置非空
- **验证**: `require("lint").linters_by_ft` 非空
- **验证方式**: API 查询

### TC-PLG-050: json linter 为 jsonlint
- **验证**: `require("lint").linters_by_ft.json` 包含 `"jsonlint"`
- **验证方式**: API 查询

### TC-PLG-051: python linter 为 ruff
- **验证**: `require("lint").linters_by_ft.python` 包含 `"ruff"`
- **验证方式**: API 查询

---

## 4.13 conform.nvim (lsp.lua)

### TC-PLG-052: conform 加载
- **验证**: `require("conform")` 不报错
- **验证方式**: API 查询

### TC-PLG-053: `<leader><CR>` 格式化映射
- **验证**: `vim.fn.maparg("<leader><CR>", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-054: ConformFormat 命令存在
- **验证**: `vim.fn.exists(":ConformFormat") == 2`
- **验证方式**: API 查询

### TC-PLG-055: rust 使用 rustfmt
- **验证**: `require("conform").formatters_by_ft.rust` 包含 `"rustfmt"`
- **验证方式**: API 查询

### TC-PLG-056: format_on_save 禁用
- **验证**: conform 配置中 `format_on_save == false`
- **验证方式**: 配置检查

---

## 4.14 barbecue.nvim (lsp.lua)

### TC-PLG-057: barbecue 加载
- **验证**: `require("barbecue")` 不报错
- **验证方式**: API 查询

---

## 4.15 inc-rename.nvim (lsp.lua)

### TC-PLG-058: `<leader>rn` 在 normal 模式触发 IncRename
- **验证**: `vim.fn.maparg("<leader>rn", "n")` 包含 `IncRename`
- **验证方式**: API 查询

---

## 4.16 aerial.nvim (lsp.lua)

### TC-PLG-059: `gj` 跳到下一个函数/符号
- **验证**: `vim.fn.maparg("gj", "n")` 包含 `AerialNext`
- **验证方式**: API 查询

### TC-PLG-060: `gk` 跳到上一个函数/符号
- **验证**: `vim.fn.maparg("gk", "n")` 包含 `AerialPrev`
- **验证方式**: API 查询

---

## 4.17 indent-blankline (lsp.lua)

### TC-PLG-061: `<leader>ui` 切换缩进指引
- **验证**: `vim.fn.maparg("<leader>ui", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-062: 默认禁用（indent_blankline_hide=true）
- **验证**: indent-blankline 在启动时 disabled
- **验证方式**: `require("ibl.config").get_config(0).enabled == false`

---

## 4.18 lazydev.nvim (lsp.lua)

### TC-PLG-063: lazydev 在 lua 文件中加载
- **前置条件**: 打开 .lua 文件
- **验证**: lazydev 提供 vim.uv 类型补全
- **验证方式**: 功能测试

---

## 4.19 nvim-cmp (cmp.lua)

### TC-PLG-064: nvim-cmp 加载
- **验证**: `require("cmp")` 不报错
- **验证方式**: API 查询

### TC-PLG-065: Tab 键在 cmp 可见且有选中时确认补全
- **验证**: cmp 映射中 `<Tab>` 非空且为函数
- **验证方式**: 配置检查

### TC-PLG-066: Tab 键在 luasnip 可展开时展开
- **验证**: Tab fallback 包含 luasnip.expand 逻辑
- **验证方式**: 配置检查

### TC-PLG-067: `<S-Tab>` 在 luasnip 中向前跳
- **验证**: cmp 映射中 `<S-Tab>` 包含 luasnip.jump(-1)
- **验证方式**: 配置检查

### TC-PLG-068: `<CR>` 确认补全或正常换行
- **验证**: CR 映射为条件函数
- **验证方式**: 配置检查

### TC-PLG-069: `<C-c>` 取消补全或清除 copilot
- **验证**: C-c 映射包含 cmp.abort 和 copilot.Clear
- **验证方式**: 配置检查

### TC-PLG-070: `<Up>/<Down>` 选择补全项或 copilot 建议
- **验证**: Up/Down 映射为条件函数
- **验证方式**: 配置检查

### TC-PLG-071: `<Right>` 跳 luasnip 或接受 copilot 行
- **验证**: Right 映射为条件函数
- **验证方式**: 配置检查

### TC-PLG-072: ghost_text 禁用
- **验证**: cmp 配置 `experimental.ghost_text == false`
- **验证方式**: 配置检查

### TC-PLG-073: cmdline `/` `?` 补全配置
- **验证**: cmp.cmdline 为 `/` 和 `?` 设置了 buffer 源
- **验证方式**: 配置检查

### TC-PLG-074: cmdline `:` 补全配置
- **验证**: cmp.cmdline 为 `:` 设置了 cmdline + path + history 源
- **验证方式**: 配置检查

### TC-PLG-075: cmp 源优先级排序正确
- **验证**: luasnip (150) > nvim_lsp (150) > buffer (120) > cmp_tabnine (90)
- **验证方式**: 配置检查

---

## 4.20 Gitsigns (git.lua)

### TC-PLG-076: `<leader>hr` 重置 hunk
- **验证**: `vim.fn.maparg("<leader>hr", "n")` 包含 `Gitsigns reset_hunk`
- **验证方式**: API 查询

### TC-PLG-077: `<leader>hp` 预览 hunk inline
- **验证**: `vim.fn.maparg("<leader>hp", "n")` 包含 `preview_hunk_inline`
- **验证方式**: API 查询

### TC-PLG-078: `<leader>hq` 将 hunk 设为 quickfix
- **验证**: `vim.fn.maparg("<leader>hq", "n")` 包含 `setqflist`
- **验证方式**: API 查询

### TC-PLG-079: `<leader>sd` 在新 tab 中 diff
- **验证**: `vim.fn.maparg("<leader>sd", "n")` 非空（函数类型）
- **验证方式**: API 查询

### TC-PLG-080: `<leader>hs` stage hunk
- **验证**: `vim.fn.maparg("<leader>hs", "n")` 包含 `stage_hunk`
- **验证方式**: API 查询

### TC-PLG-081: `<leader>hb` blame line
- **验证**: `vim.fn.maparg("<leader>hb", "")` 包含 `blame_line`
- **验证方式**: API 查询

### TC-PLG-082: `<leader>hB` 全文 blame
- **验证**: `vim.fn.maparg("<leader>hB", "")` 包含 `blame`
- **验证方式**: API 查询

### TC-PLG-083: `]c` 下一个 change
- **验证**: `vim.fn.maparg("]c", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-084: `[c` 上一个 change
- **验证**: `vim.fn.maparg("[c", "n")` 非空
- **验证方式**: API 查询

---

## 4.21 Diffview (git.lua)

### TC-PLG-085: `<leader>sD` 打开 DiffviewOpen
- **验证**: `vim.fn.maparg("<leader>sD", "n")` 包含 `DiffviewOpen`
- **验证方式**: API 查询

---

## 4.22 gitlinker (git.lua)

### TC-PLG-086: gitlinker 加载
- **验证**: `require("gitlinker")` 不报错
- **验证方式**: API 查询

---

## 4.23 DAP (debug.lua)

### TC-PLG-087: nvim-dap 加载
- **验证**: `require("dap")` 不报错
- **验证方式**: API 查询

### TC-PLG-088: persistent-breakpoints 加载
- **验证**: 断点在 BufReadPost 时自动加载
- **验证方式**: 配置检查

### TC-PLG-089: `<leader>xb` 切换断点
- **验证**: `vim.fn.maparg("<leader>xb", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-090: `<leader>xB` 条件断点
- **验证**: `vim.fn.maparg("<leader>xB", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-091: `<leader>Dl` 运行上次调试
- **验证**: `vim.fn.maparg("<leader>Dl", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-092: `<leader>dr` 切换 REPL
- **验证**: `vim.fn.maparg("<leader>dr", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-093: DAP 监听器设置正确
- **验证**: `require("dap").listeners.after["event_initialized"]["nvim-dap-noui"]` 非 nil
- **验证方式**: API 查询

### TC-PLG-094: DAP 终止时 debugging_status 重置为 "NoDebug"
- **验证**: 检查 listeners.before.event_terminated 存在
- **验证方式**: API 查询

### TC-PLG-095: lua 调试配置存在
- **验证**: `require("dap").configurations.lua` 非空
- **验证方式**: API 查询

### TC-PLG-096: `<leader>ud` 切换 DapView
- **验证**: `vim.fn.maparg("<leader>ud", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-097: `<leader>uv` 切换虚拟文本
- **验证**: `vim.fn.maparg("<leader>uv", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-098: dap-view winbar 配置正确
- **验证**: dap-view sections 包含 repl, console, watches 等
- **验证方式**: 配置检查

---

## 4.24 Theme (theme.lua)

### TC-PLG-099: dracula 主题加载
- **验证**: `vim.g.colors_name == "dracula"`
- **验证方式**: API 查询

### TC-PLG-100: FaintSelected highlight group 存在
- **验证**: `vim.api.nvim_get_hl(0, {name="FaintSelected"})` 非空
- **验证方式**: API 查询

### TC-PLG-101: CursorLine 背景设为空
- **验证**: `vim.api.nvim_get_hl(0, {name="CursorLine"}).bg` 为 nil 或空
- **验证方式**: API 查询

---

## 4.25 Noice (theme.lua)

### TC-PLG-102: noice 加载
- **验证**: `require("noice")` 不报错
- **验证方式**: API 查询

### TC-PLG-103: `<leader>im` 显示消息历史
- **验证**: `vim.fn.maparg("<leader>im", "n")` 包含 `NoiceHistory`
- **验证方式**: API 查询

### TC-PLG-104: vim.print 被重定义为 vim.notify
- **验证**: `vim.print("test")` 通过 noice 显示通知
- **验证方式**: 功能测试

### TC-PLG-105: vim.print_silent 保留为原始 print
- **验证**: `vim.print_silent` 函数存在
- **验证方式**: API 查询

### TC-PLG-106: noice FileType autocmd 中 gf 可用
- **前置条件**: noice 消息窗口中
- **验证**: `vim.fn.maparg("gf", "n")` 在 noice buffer 中存在
- **验证方式**: API 查询

---

## 4.26 Lualine (theme.lua)

### TC-PLG-107: lualine 加载
- **验证**: `require("lualine")` 不报错
- **验证方式**: API 查询

### TC-PLG-108: lualine sections 配置包含 filename
- **验证**: lualine_a 包含 filename（path=1）
- **验证方式**: 配置检查

### TC-PLG-109: lualine global_status = true
- **验证**: 全局状态栏配置
- **验证方式**: 配置检查

### TC-PLG-110: lualine 系统图标函数工作
- **验证**: 状态栏末端显示系统图标
- **验证方式**: 功能测试（capture-pane 或 API 检查 lualine 配置）

---

## 4.27 Scrollbar (theme.lua)

### TC-PLG-111: scrollbar 加载
- **验证**: `require("scrollbar")` 不报错
- **验证方式**: API 查询

### TC-PLG-112: `<leader>ub` 切换 scrollbar
- **验证**: `vim.fn.maparg("<leader>ub", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-113: scrollbar 默认隐藏
- **验证**: `vim.g.scroll_bar_hide == true` 时 scrollbar 初始 show=false
- **验证方式**: 配置检查

---

## 4.28 hlslens (theme.lua)

### TC-PLG-114: hlslens 加载
- **验证**: 搜索时 scrollbar 显示搜索标记
- **验证方式**: 功能测试

---

## 4.29 vimade (theme.lua)

### TC-PLG-115: vimade 加载
- **验证**: `require("vimade")` 不报错（或插件已加载）
- **验证方式**: API 查询

### TC-PLG-116: vimade fadelevel = 0.66
- **验证**: 非活跃 buffer 淡化
- **验证方式**: 配置检查

---

## 4.30 Snacks.nvim (miscellaneous.lua)

### TC-PLG-117: `<leader>bb` 打开 buffer picker
- **验证**: `vim.fn.maparg("<leader>bb", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-118: `<leader>bB` grep buffers
- **验证**: `vim.fn.maparg("<leader>bB", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-119: `<leader>/` 全局 grep
- **验证**: `vim.fn.maparg("<leader>/", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-120: `<c-/>` 行搜索
- **验证**: `vim.fn.maparg("<c-/>", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-121: `<leader>fe` 文件浏览
- **验证**: `vim.fn.maparg("<leader>fe", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-122: `<leader>ff` 智能文件查找
- **验证**: `vim.fn.maparg("<leader>ff", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-123: `<leader>fc` 查找配置文件
- **验证**: `vim.fn.maparg("<leader>fc", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-124: `<leader>fo` 最近文件
- **验证**: `vim.fn.maparg("<leader>fo", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-125: `<leader>ss` LSP 符号
- **验证**: `vim.fn.maparg("<leader>ss", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-126: `<leader>sS` 工作区符号
- **验证**: `vim.fn.maparg("<leader>sS", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-127: `<leader>gd` Git diff
- **验证**: `vim.fn.maparg("<leader>gd", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-128: `<leader>lt` TODO 注释
- **验证**: `vim.fn.maparg("<leader>lt", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-129: `<leader>sk` keymaps
- **验证**: `vim.fn.maparg("<leader>sk", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-130: `<leader>jJ` 工作区诊断
- **验证**: `vim.fn.maparg("<leader>jJ", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-131: `<leader>jj` buffer 诊断
- **验证**: `vim.fn.maparg("<leader>jj", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-132: `gd` 跳到定义
- **验证**: `vim.fn.maparg("gd", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-133: `gr` 查找引用
- **验证**: `vim.fn.maparg("gr", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-134: `gi` 跳到实现
- **验证**: `vim.fn.maparg("gi", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-135: `gy` 跳到类型定义
- **验证**: `vim.fn.maparg("gy", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-136: `<leader>tT` 恢复上次 picker
- **验证**: `vim.fn.maparg("<leader>tT", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-137: `<leader>pp` 命令历史
- **验证**: `vim.fn.maparg("<leader>pp", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-138: `<leader>pP` 所有命令
- **验证**: `vim.fn.maparg("<leader>pP", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-139: `<leader>zz` zoxide 导航
- **验证**: `vim.fn.maparg("<leader>zz", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-140: visual 模式的 picker 带预填充
- **验证**: `vim.fn.maparg("<leader>/", "v")` 非空
- **验证方式**: API 查询

### TC-PLG-141: snacks picker layout 为 dropdown
- **验证**: Snacks picker 配置 `layout.preset == "dropdown"`
- **验证方式**: 配置检查

### TC-PLG-142: snacks explorer layout 为 dropdown + preview
- **验证**: explorer 配置 preview=true
- **验证方式**: 配置检查

---

## 4.31 nvim-ufo (miscellaneous.lua)

### TC-PLG-143: ufo 加载
- **验证**: `require("ufo")` 不报错
- **验证方式**: API 查询

### TC-PLG-144: `zR` 打开所有折叠
- **验证**: `vim.fn.maparg("zR", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-145: `zM` 关闭所有折叠
- **验证**: `vim.fn.maparg("zM", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-146: foldlevel 设为 99
- **验证**: `vim.o.foldlevel == 99`
- **验证方式**: API 查询

---

## 4.32 Treesitter (miscellaneous.lua)

### TC-PLG-147: treesitter 加载
- **验证**: `require("nvim-treesitter")` 不报错
- **验证方式**: API 查询

### TC-PLG-148: 确保安装的语言列表包含 bash, python, cpp 等
- **验证**: ensure_installed 包含核心语言
- **验证方式**: 配置检查

### TC-PLG-149: zsh 注册为 bash parser
- **验证**: `vim.treesitter.language.get_lang("zsh") == "bash"`
- **验证方式**: API 查询

### TC-PLG-150: rainbow-delimiters 集成
- **验证**: rainbow delimiters 启用
- **验证方式**: 配置检查

---

## 4.33 auto-save (miscellaneous.lua)

### TC-PLG-151: auto-save 加载
- **验证**: `require("auto-save")` 不报错
- **验证方式**: API 查询

### TC-PLG-152: 触发事件包含 InsertLeave 和 TextChanged
- **验证**: 配置中 trigger_events 正确
- **验证方式**: 配置检查

---

## 4.34 yanky.nvim (miscellaneous.lua)

### TC-PLG-153: `<leader>yy` 打开 yanky picker
- **验证**: `vim.fn.maparg("<leader>yy", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-154: yanky ring history_length = 1000
- **验证**: yanky 配置 history_length == 1000
- **验证方式**: 配置检查

### TC-PLG-155: yanky 不自动同步系统剪贴板
- **验证**: system_clipboard.sync_with_ring == false
- **验证方式**: 配置检查

### TC-PLG-156: yanky 忽略默认寄存器
- **验证**: ignore_registers 包含 `'"'`
- **验证方式**: 配置检查

---

## 4.35 Copilot (ai.lua)

### TC-PLG-157: copilot 加载（node 可执行时）
- **前置条件**: `vim.fn.executable("node") == 1`
- **验证**: copilot 插件已加载
- **验证方式**: API 查询

### TC-PLG-158: `<D-CR>` 在 insert 模式接受 copilot 建议
- **验证**: `vim.fn.maparg("<D-CR>", "i")` 非空
- **验证方式**: API 查询

---

## 4.36 gp.nvim (ai.lua)

### TC-PLG-159: gp.nvim 加载
- **验证**: `require("gp")` 不报错
- **验证方式**: API 查询

### TC-PLG-160: `<leader>ae` 触发 Rewrite
- **验证**: `vim.fn.maparg("<leader>ae", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-161: Rewrite 命令存在
- **验证**: `vim.fn.exists(":Rewrite") == 2`
- **验证方式**: API 查询

---

## 4.37 Rustaceanvim (rust.lua)

### TC-PLG-162: rustaceanvim 配置函数存在
- **验证**: `type(vim.g.rustaceanvim) == "function"`（加载前）
- **验证方式**: API 查询

### TC-PLG-163: `<leader>ge` rust 相关诊断
- **验证**: `vim.fn.maparg("<leader>ge", "n")` 包含 `relatedDiagnostics`
- **验证方式**: API 查询

### TC-PLG-164: `J` 在 rust 文件中 join lines
- **验证**: `vim.fn.maparg("J", "n")` 包含 `joinLines`
- **验证方式**: API 查询

### TC-PLG-165: rust 文件中 `gD` 打开文档
- **前置条件**: 打开 .rs 文件
- **验证**: `vim.fn.maparg("gD", "n")` 在 rust buffer 中包含 `openDocs`
- **验证方式**: API 查询

---

## 4.38 crates.nvim (rust.lua)

### TC-PLG-166: crates.nvim 在 Cargo.toml 中加载
- **前置条件**: 打开 Cargo.toml
- **验证**: crates 插件激活
- **验证方式**: 功能测试

---

## 4.39 go.nvim (go.lua)

### TC-PLG-167: go.nvim 加载
- **前置条件**: 打开 .go 文件
- **验证**: `require("go")` 不报错
- **验证方式**: API 查询

---

## 4.40 Python DAP (python.lua)

### TC-PLG-168: venv-selector 在 python 文件中加载
- **前置条件**: 打开 .py 文件且 python 可执行
- **验证**: `require("venv-selector")` 不报错
- **验证方式**: API 查询

### TC-PLG-169: dap-python 配置
- **前置条件**: python 可执行
- **验证**: `require("dap").configurations.python` 非空
- **验证方式**: API 查询

### TC-PLG-170: debugpy 配置包含默认 debug 配置
- **验证**: dap.configurations.python 包含 "Debugpy: Default debug configuration"
- **验证方式**: API 查询

---

## 4.41 hex.nvim (hex.lua)

### TC-PLG-171: hex.nvim 禁用（read_binary_with_xxd=false）
- **验证**: hex 插件未加载
- **验证方式**: API 查询

---

## 4.42 obsidian.nvim (obsidian.lua)

### TC-PLG-172: obsidian.nvim 条件启用
- **验证**: 插件 enabled 依赖 `vim.g.obsidian_functions_enabled`
- **验证方式**: 配置检查

---

## 4.43 Overseer (task.lua)

### TC-PLG-173: `<leader>ll` 打开最近任务
- **验证**: `vim.fn.maparg("<leader>ll", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-174: `<leader>lL` 切换 overseer 列表
- **验证**: `vim.fn.maparg("<leader>lL", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-175: `<leader>lm` 运行命令
- **验证**: `vim.fn.maparg("<leader>lm", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-176: `<leader>lr` 运行任务
- **验证**: `vim.fn.maparg("<leader>lr", "n")` 非空
- **验证方式**: API 查询

### TC-PLG-177: `<leader>lR` 重启上次任务
- **验证**: `vim.fn.maparg("<leader>lR", "n")` 非空
- **验证方式**: API 查询

---

## 4.44 Lazy.nvim 配置 (lazy.lua)

### TC-PLG-178: checker 启用但 notify 关闭
- **验证**: lazy 配置 checker.enabled=true, checker.notify=false
- **验证方式**: 配置检查

### TC-PLG-179: 禁用的 RTP 插件列表正确
- **验证**: disabled_plugins 包含 gzip, tarPlugin, tohtml, tutor, zipPlugin
- **验证方式**: 配置检查

---

**本模块测试用例总数: 179**
