# Test Plan Part 3: Autocmds & Custom Commands

> 测试方法: 通过 `vim.fn.exists(":CmdName")` 验证命令存在，通过触发事件 + API 查询验证行为

---

## 3.1 RunTest 命令

### TC-CMD-001: RunTest 命令存在
- **验证**: `vim.fn.exists(":RunTest") == 2`
- **验证方式**: API 查询

### TC-CMD-002: RunTest 执行 *_vimtest.lua 文件
- **前置条件**: 创建 `/tmp/test_vimtest.lua`，内容 `vim.g._test_result = "passed"`
- **测试步骤**: `:cd /tmp`，`:RunTest`
- **验证**: `vim.g._test_result == "passed"`
- **验证方式**: API 查询

### TC-CMD-003: RunTest 无测试文件时不报错
- **前置条件**: 工作目录无 `*_vimtest.lua`
- **测试步骤**: `:RunTest`
- **验证**: 无错误
- **验证方式**: API 查询

---

## 3.2 Copen 命令

### TC-CMD-004: Copen 命令存在
- **验证**: `vim.fn.exists(":Copen") == 2`
- **验证方式**: API 查询

### TC-CMD-005: Copen 打开全宽 quickfix
- **测试步骤**: `:Copen`
- **验证**: quickfix 窗口打开
- **验证方式**: API 查询 `vim.fn.getwininfo()` 中 quickfix 窗口

---

## 3.3 RunScript 命令

### TC-CMD-006: RunScript 命令存在
- **验证**: `vim.fn.exists(":RunScript") == 2`
- **验证方式**: API 查询

### TC-CMD-007: RunScript 执行 lua 文件（this_neovim runner）
- **前置条件**: 打开 lua 文件，内容 `return 42`
- **测试步骤**: `:RunScript`
- **验证**: 结果输出包含 `42`
- **验证方式**: API 查询 / 通知检查

### TC-CMD-008: RunScript 执行 python 文件
- **前置条件**: 打开 python 文件，`print("hello")`，且 python3 可执行
- **测试步骤**: `:RunScript`
- **验证**: 输出插入到 buffer（包含 "hello"）
- **验证方式**: API 查询 buffer 内容

### TC-CMD-009: RunScript 执行 shell 文件
- **前置条件**: 打开 sh 文件，`echo test`
- **测试步骤**: `:RunScript`
- **验证**: 输出包含 "test"
- **验证方式**: API 查询

### TC-CMD-010: RunScript 无 runner 时报错
- **前置条件**: 打开不支持的 filetype
- **测试步骤**: `:RunScript`
- **验证**: 通知包含 "No runner found"
- **验证方式**: 通知检查

### TC-CMD-011: RunScript 无 filetype 时报错
- **前置条件**: `vim.bo.filetype = ""`
- **测试步骤**: `:RunScript`
- **验证**: 通知包含 "No filetype"
- **验证方式**: 通知检查

### TC-CMD-012: RunScript 超时杀掉进程
- **前置条件**: Python 文件包含 `import time; time.sleep(100)`
- **测试步骤**: `:RunScript`（timeout 默认 3s）
- **验证**: 3 秒后通知超时
- **验证方式**: 延迟后检查通知

### TC-CMD-013: RunScript 在 visual 模式执行选中内容
- **前置条件**: lua 文件，选中 `return 1+1`
- **测试步骤**: 选中后 `:RunScript`
- **验证**: 输出包含 `2`
- **验证方式**: API 查询

---

## 3.4 SetBufRunner 命令

### TC-CMD-014: SetBufRunner 命令存在
- **验证**: `vim.fn.exists(":SetBufRunner") == 2`
- **验证方式**: API 查询

### TC-CMD-015: SetBufRunner 设置 buffer-local runner
- **前置条件**: 打开 lua 文件
- **测试步骤**: `:SetBufRunner echo custom_output`
- **验证**: `vim.b.runner.lua.template == "echo custom_output"`
- **验证方式**: API 查询

---

## 3.5 OverseerRestartLast 命令

### TC-CMD-016: OverseerRestartLast 命令存在
- **验证**: `vim.fn.exists(":OverseerRestartLast") == 2`
- **验证方式**: API 查询

---

## 3.6 DebugServe 命令

### TC-CMD-017: DebugServe 命令存在
- **验证**: `vim.fn.exists(":DebugServe") == 2`
- **验证方式**: API 查询

---

## 3.7 MasonInstallAll 命令

### TC-CMD-018: MasonInstallAll 命令存在
- **验证**: `vim.fn.exists(":MasonInstallAll") == 2`
- **验证方式**: API 查询

---

## 3.8 OpenLaunchJson 命令

### TC-CMD-019: OpenLaunchJson 命令存在
- **验证**: `vim.fn.exists(":OpenLaunchJson") == 2`
- **验证方式**: API 查询

### TC-CMD-020: OpenLaunchJson 打开已存在的 launch.json
- **前置条件**: 创建 `$cwd/.vscode/launch.json`
- **测试步骤**: `:OpenLaunchJson`
- **验证**: 当前 buffer 文件名包含 `launch.json`
- **验证方式**: API 查询 `vim.fn.expand("%:t")`

---

## 3.9 Tab 管理命令

### TC-CMD-021: PinTab 命令存在
- **验证**: `vim.fn.exists(":PinTab") == 2`
- **验证方式**: API 查询

### TC-CMD-022: PinTab 将当前 tab 固定
- **测试步骤**: `:PinTab`
- **验证**: `vim.g.pinned_tab` 非 nil，且 id 为当前 tabpage
- **验证方式**: API 查询

### TC-CMD-023: PinTab 将 tab 移到第一位
- **前置条件**: 2 个 tab，光标在第 2 个
- **测试步骤**: `:PinTab`
- **验证**: 当前 tab 变为第一个（`vim.fn.tabpagenr() == 1`）
- **验证方式**: API 查询

### TC-CMD-024: PinTab 带参数设置名称
- **测试步骤**: `:PinTab MyName`
- **验证**: `vim.g.pinned_tab.name == "MyName"`
- **验证方式**: API 查询

### TC-CMD-025: UnpinTab 命令存在
- **验证**: `vim.fn.exists(":UnpinTab") == 2`
- **验证方式**: API 查询

### TC-CMD-026: UnpinTab 清除固定状态
- **前置条件**: 已 PinTab
- **测试步骤**: `:UnpinTab`
- **验证**: `vim.g.pinned_tab == nil` 或 `vim.NIL`
- **验证方式**: API 查询

### TC-CMD-027: FlipPinnedTab 命令存在
- **验证**: `vim.fn.exists(":FlipPinnedTab") == 2`
- **验证方式**: API 查询

### TC-CMD-028: FlipPinnedTab 从非固定 tab 跳到固定 tab
- **前置条件**: tab 1 已固定，光标在 tab 2
- **测试步骤**: `:FlipPinnedTab`
- **验证**: 当前 tab 为固定 tab
- **验证方式**: API 查询

### TC-CMD-029: FlipPinnedTab 从固定 tab 跳回上一个 tab
- **前置条件**: 从 tab 2 跳到固定的 tab 1
- **测试步骤**: `:FlipPinnedTab`
- **验证**: 回到 tab 2
- **验证方式**: API 查询

### TC-CMD-030: FlipPinnedTab 无固定 tab 时不动作
- **前置条件**: `vim.g.pinned_tab == nil`
- **测试步骤**: `:FlipPinnedTab`
- **验证**: 无变化
- **验证方式**: API 查询

### TC-CMD-031: SetTabName 命令设置名称
- **测试步骤**: `:SetTabName Custom`
- **验证**: `vim.fn.gettabvar(vim.fn.tabpagenr(), "tabname") == "Custom"`
- **验证方式**: API 查询

### TC-CMD-032: ResetTabName 清除名称
- **前置条件**: 已设置 tabname
- **测试步骤**: `:ResetTabName`
- **验证**: `vim.fn.gettabvar(vim.fn.tabpagenr(), "tabname") == ""`
- **验证方式**: API 查询

---

## 3.10 Tab 相关 Autocmd

### TC-CMD-033: TabLeave 记录 last_tab
- **前置条件**: 2 个 tab，光标在 tab 2
- **测试步骤**: 切换到 tab 1
- **验证**: `vim.g.last_tab` 记录了原来的 tabpage id
- **验证方式**: API 查询

### TC-CMD-034: TabClosed 清理 pinned_tab
- **前置条件**: tab 1 已固定
- **测试步骤**: 关闭 tab 1
- **验证**: `vim.g.pinned_tab == nil`
- **验证方式**: API 查询

---

## 3.11 FocusGained Autocmd

### TC-CMD-035: FocusGained 触发 checktime
- **验证**: 存在 FocusGained 的 autocmd
- **验证方式**: `vim.api.nvim_get_autocmds({event="FocusGained"})` 非空

---

## 3.12 Snippet 命令

### TC-CMD-036: SnipEdit 命令存在
- **验证**: `vim.fn.exists(":SnipEdit") == 2`
- **验证方式**: API 查询

### TC-CMD-037: SnipLoad 命令存在
- **验证**: `vim.fn.exists(":SnipLoad") == 2`
- **验证方式**: API 查询

### TC-CMD-038: SnipPick 命令存在
- **验证**: `vim.fn.exists(":SnipPick") == 2`
- **验证方式**: API 查询

---

## 3.13 LuaPrint 命令

### TC-CMD-039: LuaPrint 命令存在
- **验证**: `vim.fn.exists(":LuaPrint") == 2`
- **验证方式**: API 查询

### TC-CMD-040: LuaPrint 执行并打印结果
- **前置条件**: buffer 内容 `1+1`，选中
- **测试步骤**: `:'<,'>LuaPrint`
- **验证**: 输出 `2`
- **验证方式**: 通知检查

---

## 3.14 Yanky Ring 过滤（TextYankPost autocmd）

### TC-CMD-041: TextYankPost autocmd 存在
- **验证**: `vim.api.nvim_get_autocmds({event="TextYankPost"})` 非空
- **验证方式**: API 查询

### TC-CMD-042: 短文本不进入 yanky ring
- **前置条件**: yank 少于 10 字符的文本
- **验证**: yanky history 不增长（或增长后被过滤）
- **验证方式**: 需要检查 yanky history（复杂，标记为需要 yanky API）

### TC-CMD-043: 超长文本不进入 yanky ring
- **前置条件**: yank 超过 1000 字符的文本
- **验证**: 同上
- **验证方式**: 同上

---

## 3.15 SVN 相关命令（条件启用）

### TC-CMD-044: SvnDiffThis 命令存在（svn 模块启用时）
- **前置条件**: `vim.g.modules.svn.enabled == true`
- **验证**: `vim.fn.exists(":SvnDiffThis") == 2`
- **验证方式**: API 查询

### TC-CMD-045: SvnDiffThisClose 命令存在
- **前置条件**: svn 模块启用
- **验证**: `vim.fn.exists(":SvnDiffThisClose") == 2`
- **验证方式**: API 查询

### TC-CMD-046: SvnDiffShiftVersion 命令存在
- **前置条件**: svn 模块启用
- **验证**: `vim.fn.exists(":SvnDiffShiftVersion") == 2`
- **验证方式**: API 查询

### TC-CMD-047: SvnDiffAll 命令存在
- **前置条件**: svn 模块启用
- **验证**: `vim.fn.exists(":SvnDiffAll") == 2`
- **验证方式**: API 查询

---

## 3.16 Highlight 相关 Autocmd

### TC-CMD-048: FileType autocmd 为 treesitter highlight 文件类型启用 TSBufEnable
- **前置条件**: `vim.g.use_treesitter_highlight` 包含 `"c"`
- **测试步骤**: 打开 .c 文件
- **验证**: TreeSitter highlight 已启用
- **验证方式**: `vim.treesitter.highlighter.active[bufnr]` 非 nil（或类似检查）

### TC-CMD-049: 非 treesitter 文件类型启用 syntax
- **前置条件**: 打开 .py 文件（假设不在 treesitter highlight 列表中）
- **验证**: `vim.bo.syntax == "on"` 或非空
- **验证方式**: API 查询

### TC-CMD-050: highlight_yank autocmd 存在
- **验证**: `vim.api.nvim_get_autocmds({group="highlight_yank"})` 非空
- **验证方式**: API 查询

---

## 3.17 Quickfix/Help 页面关闭

### TC-CMD-051: quickfix buffer 中 `q` 关闭
- **前置条件**: 打开 quickfix (`:copen`)
- **验证**: `vim.fn.maparg("q", "n", false, true)` 在 qf buffer 中映射到 `bd`
- **验证方式**: API 查询（buffer-local）

### TC-CMD-052: gitsigns-blame buffer 中 `q` 关闭
- **前置条件**: 打开 gitsigns-blame buffer
- **验证**: 同上
- **验证方式**: API 查询

### TC-CMD-053: help buffer 中 `q` 关闭
- **前置条件**: `:help`
- **验证**: `vim.fn.maparg("q", "n")` 在 help buffer 中映射到 `<c-w>c`
- **验证方式**: API 查询

### TC-CMD-054: man buffer 中 `q` 关闭
- **前置条件**: 打开 man page
- **验证**: 同上
- **验证方式**: API 查询

---

## 3.18 Quickfix 导航命令

### TC-CMD-055: Qnext 命令存在
- **验证**: `vim.fn.exists(":Qnext") == 2`
- **验证方式**: API 查询

### TC-CMD-056: Qprev 命令存在
- **验证**: `vim.fn.exists(":Qprev") == 2`
- **验证方式**: API 查询

### TC-CMD-057: Qnewer 命令存在
- **验证**: `vim.fn.exists(":Qnewer") == 2`
- **验证方式**: API 查询

### TC-CMD-058: Qolder 命令存在
- **验证**: `vim.fn.exists(":Qolder") == 2`
- **验证方式**: API 查询

### TC-CMD-059: Qnext 在列表末尾循环到开头
- **前置条件**: quickfix 列表有 3 项，光标在最后
- **测试步骤**: `:Qnext`
- **验证**: 跳到第一项（`cfirst` 被调用）
- **验证方式**: API 查询光标位置

### TC-CMD-060: Qprev 在列表开头循环到末尾
- **前置条件**: quickfix 列表有 3 项，光标在第一个
- **测试步骤**: `:Qprev`
- **验证**: 跳到最后一项
- **验证方式**: API 查询

---

## 3.19 Split 命令

### TC-CMD-061: Split 命令存在
- **验证**: `vim.fn.exists(":Split") == 2`
- **验证方式**: API 查询

### TC-CMD-062: Vsplit 命令存在
- **验证**: `vim.fn.exists(":Vsplit") == 2`
- **验证方式**: API 查询

### TC-CMD-063: Split 后光标在新窗口
- **测试步骤**: `:Split`
- **验证**: 当前窗口在下方新窗口
- **验证方式**: API 查询窗口位置

---

## 3.20 OldFiles Picker

### TC-CMD-064: SnackOldfiles 命令存在
- **验证**: `vim.fn.exists(":SnackOldfiles") == 2`
- **验证方式**: API 查询

---

## 3.21 Bookmark 命令

### TC-CMD-065: BookmarkGrepMarkedFiles 命令存在
- **验证**: `vim.fn.exists(":BookmarkGrepMarkedFiles") == 2`
- **验证方式**: API 查询

### TC-CMD-066: BookmarkSnackPicker 命令存在
- **验证**: `vim.fn.exists(":BookmarkSnackPicker") == 2`
- **验证方式**: API 查询

### TC-CMD-067: BookmarkEditNameAtCursor 命令存在
- **验证**: `vim.fn.exists(":BookmarkEditNameAtCursor") == 2`
- **验证方式**: API 查询

### TC-CMD-068: DeleteBookmarkAtCursor 命令存在
- **验证**: `vim.fn.exists(":DeleteBookmarkAtCursor") == 2`
- **验证方式**: API 查询

### TC-CMD-069: ClearBookmark 命令存在
- **验证**: `vim.fn.exists(":ClearBookmark") == 2`
- **验证方式**: API 查询

---

## 3.22 Cursor 设置

### TC-CMD-070: guicursor 设置包含 block 和 ver25
- **验证**: `vim.o.guicursor` 包含 `block` 和 `ver25`
- **验证方式**: API 查询

### TC-CMD-071: nvim 0.11+ 时 guicursor 包含 `t:ver25`
- **前置条件**: `vim.fn.has("nvim-0.11") == 1`
- **验证**: `vim.o.guicursor` 包含 `t:ver25`
- **验证方式**: API 查询

---

## 3.23 Neovide 命令

### TC-CMD-072: NeovideNew 命令存在
- **验证**: `vim.fn.exists(":NeovideNew") == 2`
- **验证方式**: API 查询

### TC-CMD-073: NeovideTransparentToggle 命令存在
- **验证**: `vim.fn.exists(":NeovideTransparentToggle") == 2`
- **验证方式**: API 查询

### TC-CMD-074: NeovideTransparentToggle 切换透明度
- **前置条件**: `vim.g.neovide_background_color` 设置了带 alpha 的颜色
- **测试步骤**: 执行两次 `:NeovideTransparentToggle`
- **验证**: 第一次截断到 7 字符，第二次恢复原值
- **验证方式**: API 查询

---

## 3.24 SearchHistory 命令

### TC-CMD-075: SearchHistory 命令存在
- **验证**: `vim.fn.exists(":SearchHistory") == 2`
- **验证方式**: API 查询

---

## 3.25 ThrowAndReveal 命令

### TC-CMD-076: ThrowAndReveal 命令存在
- **验证**: `vim.fn.exists(":ThrowAndReveal") == 2`
- **验证方式**: API 查询

### TC-CMD-077: ThrowAndReveal l 创建右侧窗口并移入 buffer
- **前置条件**: 单窗口，打开文件 A
- **测试步骤**: `:ThrowAndReveal l`
- **验证**: 右侧新窗口显示文件 A，左侧显示历史 buffer
- **验证方式**: API 查询窗口和 buffer

### TC-CMD-078: ThrowAndReveal 已有右侧窗口时直接使用
- **前置条件**: 两个窗口（左右分割）
- **测试步骤**: `:ThrowAndReveal l`
- **验证**: 不创建新窗口，将 buffer 移到右侧已有窗口
- **验证方式**: API 查询

---

## 3.26 Code 命令

### TC-CMD-079: Code 命令存在
- **验证**: `vim.fn.exists(":Code") == 2`
- **验证方式**: API 查询

---

## 3.27 CopyFilePath 命令

### TC-CMD-080: CopyFilePath 命令存在
- **验证**: `vim.fn.exists(":CopyFilePath") == 2`
- **验证方式**: API 查询

### TC-CMD-081: CopyFilePath full 复制完整路径
- **前置条件**: 打开 `/tmp/testfile.txt`
- **测试步骤**: `:CopyFilePath full`
- **验证**: `vim.fn.getreg("*")` 为 `/tmp/testfile.txt`
- **验证方式**: API 查询

### TC-CMD-082: CopyFilePath relative 复制相对路径
- **前置条件**: cwd 为 `/tmp`，打开 `/tmp/sub/file.txt`
- **测试步骤**: `:CopyFilePath relative`
- **验证**: `vim.fn.getreg("*")` 为 `sub/file.txt`
- **验证方式**: API 查询

### TC-CMD-083: CopyFilePath dir 复制 cwd
- **测试步骤**: `:CopyFilePath dir`
- **验证**: `vim.fn.getreg("*") == vim.fn.getcwd()`
- **验证方式**: API 查询

### TC-CMD-084: CopyFilePath filename 只复制文件名
- **前置条件**: 打开 `/tmp/testfile.txt`
- **测试步骤**: `:CopyFilePath filename`
- **验证**: `vim.fn.getreg("*") == "testfile.txt"`
- **验证方式**: API 查询

### TC-CMD-085: CopyFilePath line 复制文件名:行号
- **前置条件**: 光标在第 5 行
- **测试步骤**: `:CopyFilePath line`
- **验证**: `vim.fn.getreg("*")` 匹配 `filename:5`
- **验证方式**: API 查询

---

## 3.28 Macro 录制 Autocmd

### TC-CMD-086: RecordingEnter 设置 recording_status = true
- **测试步骤**: 开始录制宏 (`qq`)
- **验证**: `vim.g.recording_status == true`
- **验证方式**: API 查询

### TC-CMD-087: RecordingLeave 设置 recording_status = false
- **测试步骤**: 停止录制 (`q`)
- **验证**: `vim.g.recording_status == false`
- **验证方式**: API 查询

---

## 3.29 VimEnter/VimLeave Autocmd

### TC-CMD-088: VimEnter autocmd 存在
- **验证**: `vim.api.nvim_get_autocmds({event="VimEnter"})` 中有 LAST_WORKING_DIRECTORY 相关回调
- **验证方式**: API 查询

### TC-CMD-089: VimLeavePre 保存工作目录
- **验证**: VimLeavePre autocmd 存在
- **验证方式**: `vim.api.nvim_get_autocmds({event="VimLeavePre"})` 非空

### TC-CMD-090: VimLeave 尝试 detach tmux
- **验证**: VimLeave autocmd 存在
- **验证方式**: `vim.api.nvim_get_autocmds({event="VimLeave"})` 非空

---

## 3.30 Markdown / Obsidian Autocmd

### TC-CMD-091: BufRead markdown autocmd 存在
- **验证**: `vim.api.nvim_get_autocmds({group="markdown"})` 非空
- **验证方式**: API 查询

### TC-CMD-092: markdown buffer 中 `<leader>pi` 映射
- **前置条件**: 打开 .md 文件
- **验证**: `vim.fn.maparg("<leader>pi", "n")` 非空（buffer-local）
- **验证方式**: API 查询

---

## 3.31 Navigation Cd 命令

### TC-CMD-093: Cd 命令存在
- **验证**: `vim.fn.exists(":Cd") == 2`
- **验证方式**: API 查询

### TC-CMD-094: Cd 改变工作目录
- **前置条件**: 当前 cwd 不是 /tmp
- **测试步骤**: `:Cd /tmp`
- **验证**: `vim.fn.getcwd() == "/tmp"`
- **验证方式**: API 查询

---

## 3.32 Lint 命令和 Autocmd

### TC-CMD-095: Lint 命令存在
- **验证**: `vim.fn.exists(":Lint") == 2`
- **验证方式**: API 查询

### TC-CMD-096: BufWritePost 触发 lint
- **验证**: `vim.api.nvim_get_autocmds({event="BufWritePost"})` 中有 lint 回调
- **验证方式**: API 查询

### TC-CMD-097: LintInfo 命令存在
- **验证**: `vim.fn.exists(":LintInfo") == 2`
- **验证方式**: API 查询

---

## 3.33 Dap Float 关闭 Autocmd

### TC-CMD-098: dap-float FileType autocmd 存在
- **验证**: 存在 dap-float 的 FileType autocmd
- **验证方式**: API 查询 autocmds

### TC-CMD-099: dap-float 中 `<esc>` 和 `q` 关闭窗口
- **前置条件**: 打开 dap-float 类型的 buffer
- **验证**: `vim.fn.maparg("q", "n")` 和 `vim.fn.maparg("<esc>", "n")` 在该 buffer 中包含 `close`
- **验证方式**: API 查询

---

## 3.34 DapTerminate 命令

### TC-CMD-100: DapTerminate 命令存在
- **验证**: `vim.fn.exists(":DapTerminate") == 2`
- **验证方式**: API 查询

---

## 3.35 Lcmd / Term 命令

### TC-CMD-101: Lcmd 命令存在
- **验证**: `vim.fn.exists(":Lcmd") == 2`
- **验证方式**: API 查询

### TC-CMD-102: Lcmdv 命令存在
- **验证**: `vim.fn.exists(":Lcmdv") == 2`
- **验证方式**: API 查询

### TC-CMD-103: Lcmdh 命令存在
- **验证**: `vim.fn.exists(":Lcmdh") == 2`
- **验证方式**: API 查询

### TC-CMD-104: Term 命令存在
- **验证**: `vim.fn.exists(":Term") == 2`
- **验证方式**: API 查询

### TC-CMD-105: Termv 命令存在
- **验证**: `vim.fn.exists(":Termv") == 2`
- **验证方式**: API 查询

### TC-CMD-106: Termh 命令存在
- **验证**: `vim.fn.exists(":Termh") == 2`
- **验证方式**: API 查询

### TC-CMD-107: Lcmd 打开新 buffer 并设置 filetype=lua
- **测试步骤**: `:Lcmd`
- **验证**: 新窗口打开，`vim.bo.filetype == "lua"`
- **验证方式**: API 查询

### TC-CMD-108: Term 打开终端
- **测试步骤**: `:Term`
- **验证**: 新窗口打开，buffer 名以 `term://` 开头
- **验证方式**: API 查询

---

## 3.36 Diagnostics 配置

### TC-CMD-109: virtual_text 禁用
- **验证**: `vim.diagnostic.config().virtual_text == false`
- **验证方式**: API 查询

### TC-CMD-110: signs 启用
- **验证**: `vim.diagnostic.config().signs == true`
- **验证方式**: API 查询

### TC-CMD-111: underline 启用
- **验证**: `vim.diagnostic.config().underline == true`
- **验证方式**: API 查询

### TC-CMD-112: update_in_insert 禁用
- **验证**: `vim.diagnostic.config().update_in_insert == false`
- **验证方式**: API 查询

### TC-CMD-113: severity_sort 启用
- **验证**: `vim.diagnostic.config().severity_sort == true`
- **验证方式**: API 查询

### TC-CMD-114: float border = "rounded"
- **验证**: `vim.diagnostic.config().float.border == "rounded"`
- **验证方式**: API 查询

---

## 3.37 Hex/Binary Autocmd（条件启用）

### TC-CMD-115: read_binary_with_xxd=false 时无 hex autocmd
- **验证**: 不存在 `*.bin` 的 BufReadPost autocmd（或被禁用）
- **验证方式**: API 查询

---

## 3.38 OSC52 Clipboard Sync

### TC-CMD-116: TextYankPost autocmd 包含 OSC52 copy
- **验证**: TextYankPost autocmd 中有 osc52 相关回调
- **验证方式**: API 查询

---

## 3.39 Barbecue UI

### TC-CMD-117: barbecue 默认关闭
- **验证**: barbecue UI toggle 为 false（已调用 `toggle(false)`）
- **验证方式**: 需要检查 barbecue 状态

---

## 3.40 Shell Integration

### TC-CMD-118: vim.g.shell_run 函数存在
- **验证**: `type(vim.g.shell_run) == "function"`
- **验证方式**: API 查询

### TC-CMD-119: shell_run 执行命令返回输出
- **测试步骤**: `vim.g.shell_run("echo hello")`
- **验证**: 返回值包含 "hello"
- **验证方式**: API 查询

---

## 3.41 Obsidian 命令

### TC-CMD-120: ObsUnlink 命令存在
- **验证**: `vim.fn.exists(":ObsUnlink") == 2`
- **验证方式**: API 查询

### TC-CMD-121: ObsOpen 命令存在
- **验证**: `vim.fn.exists(":ObsOpen") == 2`
- **验证方式**: API 查询

---

## 3.42 Avante FileType Autocmd

### TC-CMD-122: Avante 文件类型设置 `<c-c>` 停止生成
- **前置条件**: FileType 为 Avante
- **验证**: `vim.fn.maparg("<c-c>", "n")` 在 Avante buffer 中映射到 stop
- **验证方式**: API 查询

---

## 3.43 TelescopeAutoCommands

### TC-CMD-123: TelescopeAutoCommands 命令存在
- **验证**: `vim.fn.exists(":TelescopeAutoCommands") == 2`
- **验证方式**: API 查询

---

## 3.44 Task 管理命令

### TC-CMD-124: TaskLoad 命令存在
- **验证**: `vim.fn.exists(":TaskLoad") == 2`
- **验证方式**: API 查询

### TC-CMD-125: TaskEdit 命令存在
- **验证**: `vim.fn.exists(":TaskEdit") == 2`
- **验证方式**: API 查询

---

**本模块测试用例总数: 125**
