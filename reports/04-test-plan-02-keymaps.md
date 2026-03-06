# Test Plan Part 2: Keymaps

> 测试方法: 通过 `vim.fn.maparg()` 验证映射存在性，通过 `nvim_feedkeys` + API 查询验证行为
> 对于需要 UI 交互的映射，标注验证方式

---

## 2.1 基础编辑映射

### TC-KEY-001: `*` 不自动跳转到下一个
- **前置条件**: buffer 包含多处 "hello"，光标在第一个 "hello" 上
- **测试步骤**: `nvim_feedkeys("*", "x", false)`
- **验证**: 光标仍在原位（行号不变）
- **验证方式**: API 查询光标位置

### TC-KEY-002: `Y` 映射到 `"*y`（系统剪贴板 yank）
- **验证**: `vim.fn.maparg("Y", "n")` 包含 `"*y`
- **验证方式**: API 查询

### TC-KEY-003: `Y` 在 visual 模式也映射
- **验证**: `vim.fn.maparg("Y", "v")` 包含 `"*y`
- **验证方式**: API 查询

### TC-KEY-004: `<D-v>` 在 insert 模式粘贴剪贴板
- **验证**: `vim.fn.maparg("<D-v>", "!")` 包含 `<C-R>+`
- **验证方式**: API 查询

### TC-KEY-005: `<D-v>` 在 terminal 模式粘贴
- **验证**: `vim.fn.maparg("<D-v>", "t")` 非空
- **验证方式**: API 查询

### TC-KEY-006: `<D-v>` 在 command 模式粘贴
- **验证**: `vim.fn.maparg("<D-v>", "c")` 包含 `<C-r>+`
- **验证方式**: API 查询

---

## 2.2 Command 模式映射

### TC-KEY-007: `<C-e>` 在 command 模式跳到末尾
- **验证**: `vim.fn.maparg("<C-e>", "c")` 包含 `<end>`
- **验证方式**: API 查询

### TC-KEY-008: `<C-a>` 在 command 模式跳到开头
- **验证**: `vim.fn.maparg("<C-a>", "c")` 包含 `<home>`
- **验证方式**: API 查询

---

## 2.3 LuaPrint

### TC-KEY-009: `<leader>pr` 在 visual 模式执行 LuaPrint
- **验证**: `vim.fn.maparg("<leader>pr", "v")` 包含 `LuaPrint`
- **验证方式**: API 查询

---

## 2.4 路径复制映射

### TC-KEY-010: `<leader>yd` 复制工作目录路径
- **验证**: `vim.fn.maparg("<leader>yd", "n")` 包含 `CopyFilePath dir`
- **验证方式**: API 查询

### TC-KEY-011: `<leader>yp` 复制完整路径
- **验证**: `vim.fn.maparg("<leader>yp", "n")` 包含 `CopyFilePath full`
- **验证方式**: API 查询

### TC-KEY-012: `<leader>yr` 复制相对路径
- **验证**: `vim.fn.maparg("<leader>yr", "n")` 包含 `CopyFilePath relative`
- **验证方式**: API 查询

### TC-KEY-013: `<leader>yf` 复制文件名
- **验证**: `vim.fn.maparg("<leader>yf", "n")` 包含 `CopyFilePath filename`
- **验证方式**: API 查询

### TC-KEY-014: `<leader>yl` 复制文件名:行号
- **验证**: `vim.fn.maparg("<leader>yl", "n")` 包含 `CopyFilePath line`
- **验证方式**: API 查询

### TC-KEY-015: 路径复制也支持 visual 模式
- **验证**: `vim.fn.maparg("<leader>yd", "v")` 非空
- **验证方式**: API 查询

---

## 2.5 Inc-Rename

### TC-KEY-016: `<leader>rn` 在 visual 模式使用 IncRename
- **验证**: `vim.fn.maparg("<leader>rn", "v")` 包含 `IncRename`
- **验证方式**: API 查询

---

## 2.6 Filetype 条件映射

### TC-KEY-017: C/C++ 文件中 `<leader>hh` 切换头文件
- **前置条件**: 打开 .cpp 文件
- **验证**: `vim.fn.maparg("<leader>hh", "n")` 在 cpp buffer 中非空
- **验证方式**: API 查询（buffer-local）

### TC-KEY-018: 非 C++ 文件无 `<leader>hh` 映射
- **前置条件**: 打开 .py 文件
- **验证**: `vim.fn.maparg("<leader>hh", "n")` 在 python buffer 中为空
- **验证方式**: API 查询

---

## 2.7 窗口操作映射

### TC-KEY-019: `<leader>-` 水平分割
- **前置条件**: 单窗口
- **测试步骤**: 执行映射
- **验证**: `#vim.api.nvim_tabpage_list_wins(0) == 2`
- **验证方式**: API 查询

### TC-KEY-020: `<leader>|` 垂直分割
- **前置条件**: 单窗口
- **测试步骤**: 执行映射
- **验证**: 窗口数增加到 2
- **验证方式**: API 查询

### TC-KEY-021: `<leader>wd` 关闭当前窗口
- **前置条件**: 两个窗口
- **测试步骤**: 执行 `<leader>wd`
- **验证**: 窗口数减少
- **验证方式**: API 查询

### TC-KEY-022: `<Esc>` 清除搜索高亮
- **前置条件**: 搜索了某个词（hlsearch 激活）
- **测试步骤**: 按 `<Esc>`
- **验证**: `vim.v.hlsearch == 0`
- **验证方式**: API 查询

### TC-KEY-023: `<leader>ps` 从系统剪贴板粘贴
- **验证**: `vim.fn.maparg("<leader>ps", "n")` 包含 `"+p`
- **验证方式**: API 查询

---

## 2.8 窗口最大化

### TC-KEY-024: `<leader>wm` 第一次最大化窗口
- **前置条件**: 两个等大窗口
- **测试步骤**: 执行 `<leader>wm`
- **验证**: `vim.t.window_maximized == true`
- **验证方式**: API 查询

### TC-KEY-025: `<leader>wm` 再次执行恢复窗口
- **前置条件**: 已最大化
- **测试步骤**: 再次执行 `<leader>wm`
- **验证**: `vim.t.window_maximized == false`
- **验证方式**: API 查询

---

## 2.9 中断运行脚本

### TC-KEY-026: `<C-c>` 在有运行脚本时杀掉进程
- **前置条件**: `vim.g._current_runner` 设置为某 PID
- **测试步骤**: 执行 `<C-c>`
- **验证**: `vim.g._current_runner == nil`
- **验证方式**: API 查询

### TC-KEY-027: `<C-c>` 无运行脚本时正常传递
- **前置条件**: `vim.g._current_runner == nil`
- **验证**: 映射存在且包含 fallback 逻辑
- **验证方式**: API 查询

---

## 2.10 RunScript 映射

### TC-KEY-028: `<C-S-CR>` 映射到 RunScript
- **验证**: `vim.fn.maparg("<c-s-cr>", "n")` 包含 `RunScript`
- **验证方式**: API 查询

### TC-KEY-029: `<D-S-CR>` 映射到 RunScript
- **验证**: `vim.fn.maparg("<d-s-cr>", "n")` 包含 `RunScript`
- **验证方式**: API 查询

---

## 2.11 Comment 映射

### TC-KEY-030: `<leader>cm` 在 normal 模式触发 gcc
- **验证**: `vim.fn.maparg("<leader>cm", "n")` 非空（函数类型）
- **验证方式**: API 查询

### TC-KEY-031: `<leader>cm` 在 visual 模式触发 gc + 保持选择
- **验证**: `vim.fn.maparg("<leader>cm", "v")` 非空（函数类型）
- **验证方式**: API 查询

---

## 2.12 SVN 映射（条件启用）

### TC-KEY-032: svn 模块启用时 `<leader>sd` 存在
- **前置条件**: `vim.g.modules.svn.enabled == true`
- **验证**: `vim.fn.maparg("<leader>sd", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-033: svn 模块禁用时 `<leader>sd` (svn) 不存在
- **前置条件**: `vim.g.modules.svn.enabled == false`
- **验证**: svn 相关的 `<leader>sd` 映射不存在（可能被 git diff 占用）
- **验证方式**: API 查询

---

## 2.13 杂项映射

### TC-KEY-034: `<C-i>` 保持为 <C-i>（不被 Tab 覆盖）
- **验证**: `vim.fn.maparg("<c-i>", "n")` 为 `<C-I>` 或等价
- **验证方式**: API 查询

### TC-KEY-035: `ZA` 保存并退出所有
- **验证**: `vim.fn.maparg("ZA", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-036: `<leader>G` 打开 LazyGit
- **验证**: `vim.fn.maparg("<leader>G", "n")` 包含 `LazyGit`
- **验证方式**: API 查询

---

## 2.14 窗口移动映射（方向键）

### TC-KEY-037: `<C-J>` 在 normal 模式移动到下方窗口
- **验证**: `vim.fn.maparg("<C-J>", "n")` 非空（函数类型）
- **验证方式**: API 查询

### TC-KEY-038: `<C-H>` 在 normal 模式移动到左方窗口
- **验证**: `vim.fn.maparg("<C-H>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-039: `<C-L>` 在 normal 模式移动到右方窗口
- **验证**: `vim.fn.maparg("<C-L>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-040: `<C-K>` 在 normal 模式移动到上方窗口
- **验证**: `vim.fn.maparg("<C-K>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-041: 窗口方向键在 visual 模式有效
- **验证**: `vim.fn.maparg("<C-J>", "v")` 非空
- **验证方式**: API 查询

### TC-KEY-042: 窗口方向键在 insert 模式有效
- **验证**: `vim.fn.maparg("<C-J>", "i")` 非空
- **验证方式**: API 查询

### TC-KEY-043: 窗口方向键在 terminal 模式有效
- **验证**: `vim.fn.maparg("<C-J>", "t")` 非空
- **验证方式**: API 查询

### TC-KEY-044: 浮动窗口中方向移动被阻止
- **前置条件**: 在浮动窗口中
- **测试步骤**: 执行 `<C-J>`
- **验证**: 窗口不变（bell 响起，但无实际跳转）
- **验证方式**: API 查询当前窗口 ID 不变

---

## 2.15 ThrowAndReveal 映射

### TC-KEY-045: `<C-S-l>` 将 buffer 扔到右侧
- **验证**: `vim.fn.maparg("<c-s-l>", "n")` 非空（函数类型）
- **验证方式**: API 查询

### TC-KEY-046: `<C-S-k>` 将 buffer 扔到上方
- **验证**: `vim.fn.maparg("<c-s-k>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-047: `<C-S-j>` 将 buffer 扔到下方
- **验证**: `vim.fn.maparg("<c-s-j>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-048: `<C-S-h>` 将 buffer 扔到左侧
- **验证**: `vim.fn.maparg("<c-s-h>", "n")` 非空
- **验证方式**: API 查询

---

## 2.16 Quickfix 映射

### TC-KEY-049: `<leader>qj` 导航到下一个 quickfix
- **验证**: `vim.fn.maparg("<leader>qj", "n")` 包含 `Qnext`
- **验证方式**: API 查询

### TC-KEY-050: `<leader>qk` 导航到上一个 quickfix
- **验证**: `vim.fn.maparg("<leader>qk", "n")` 包含 `Qprev`
- **验证方式**: API 查询

### TC-KEY-051: `<leader>ql` 导航到更新的 quickfix 列表
- **验证**: `vim.fn.maparg("<leader>ql", "n")` 包含 `Qnewer`
- **验证方式**: API 查询

### TC-KEY-052: `<leader>qh` 导航到更旧的 quickfix 列表
- **验证**: `vim.fn.maparg("<leader>qh", "n")` 包含 `Qolder`
- **验证方式**: API 查询

---

## 2.17 搜索映射

### TC-KEY-053: `/` 在 visual 模式搜索选中内容
- **验证**: `vim.fn.maparg("/", "v")` 包含 `<C-R>f`
- **验证方式**: API 查询

### TC-KEY-054: `gh` 在 normal 模式先尝试 ufo peek，再 hover
- **验证**: `vim.fn.maparg("gh", "n")` 非空（函数类型）
- **验证方式**: API 查询

### TC-KEY-055: `ge` 打开 diagnostic float
- **验证**: `vim.fn.maparg("ge", "n")` 包含 `diagnostic.open_float`
- **验证方式**: API 查询

### TC-KEY-056: `ga` 执行 code_action
- **验证**: `vim.fn.maparg("ga", "n")` 包含 `code_action`
- **验证方式**: API 查询

---

## 2.18 Buffer 关闭

### TC-KEY-057: `<leader>bd` 关闭未修改 buffer
- **前置条件**: 打开未修改的 buffer
- **测试步骤**: 执行 `<leader>bd`
- **验证**: buffer 被关闭（bufnr 不在 loaded buffers 中）
- **验证方式**: API 查询

### TC-KEY-058: `<leader>bd` 不关闭已修改的 buffer
- **前置条件**: 修改 buffer 但不保存
- **测试步骤**: 执行 `<leader>bd`
- **验证**: buffer 仍然存在
- **验证方式**: API 查询

### TC-KEY-059: `<leader>bd` 强制关闭 dap-terminal buffer
- **前置条件**: buffer 名为 `[dap-terminal] Debug`
- **测试步骤**: 执行 `<leader>bd`
- **验证**: buffer 被关闭
- **验证方式**: API 查询

---

## 2.19 行移动

### TC-KEY-060: `<M-j>` 在 normal 模式下移一行
- **前置条件**: 3 行 buffer，光标在第 1 行
- **测试步骤**: 执行 `<M-j>`
- **验证**: 原第 1 行内容现在在第 2 行
- **验证方式**: API 查询 `nvim_buf_get_lines`

### TC-KEY-061: `<M-k>` 在 normal 模式上移一行
- **前置条件**: 3 行 buffer，光标在第 2 行
- **测试步骤**: 执行 `<M-k>`
- **验证**: 原第 2 行内容现在在第 1 行
- **验证方式**: API 查询 `nvim_buf_get_lines`

### TC-KEY-062: `<M-j>` 在 visual 模式移动多行
- **前置条件**: 选中 2 行
- **测试步骤**: 执行 `<M-j>`
- **验证**: 选中行下移且保持选中
- **验证方式**: API 查询

### TC-KEY-063: `<M-j>` 支持 count
- **前置条件**: 5 行 buffer，光标在第 1 行
- **测试步骤**: `2<M-j>`
- **验证**: 原第 1 行内容现在在第 3 行
- **验证方式**: API 查询

---

## 2.20 Visual till brackets

### TC-KEY-064: `[` 映射到 `t[` (till bracket)
- **验证**: `vim.fn.maparg("[", "n")` 为 `t[`
- **验证方式**: API 查询

### TC-KEY-065: `]` 映射到 `t]`
- **验证**: `vim.fn.maparg("]", "n")` 为 `t]`
- **验证方式**: API 查询

### TC-KEY-066: `{` 映射到 `t{`
- **验证**: `vim.fn.maparg("{", "n")` 为 `t{`
- **验证方式**: API 查询

### TC-KEY-067: `}` 映射到 `t}`
- **验证**: `vim.fn.maparg("}", "n")` 为 `t}`
- **验证方式**: API 查询

### TC-KEY-068: `(` 映射到 `t(`
- **验证**: `vim.fn.maparg("(", "n")` 为 `t(`
- **验证方式**: API 查询

### TC-KEY-069: `)` 映射到 `t)`
- **验证**: `vim.fn.maparg(")", "n")` 为 `t)`
- **验证方式**: API 查询

### TC-KEY-070: `,` 映射到 `t,`
- **验证**: `vim.fn.maparg(",", "n")` 为 `t,`
- **验证方式**: API 查询

### TC-KEY-071: `?` 映射到 `t?`
- **验证**: `vim.fn.maparg("?", "n")` 为 `t?`
- **验证方式**: API 查询

### TC-KEY-072: `d[` 映射到 `dt[`
- **验证**: `vim.fn.maparg("d[", "n")` 为 `dt[`
- **验证方式**: API 查询

### TC-KEY-073: visual 模式 `[` 也映射到 `t[`
- **验证**: `vim.fn.maparg("[", "v")` 为 `t[`
- **验证方式**: API 查询

---

## 2.21 Tab 操作映射

### TC-KEY-074: `<leader><tab>` 创建新 tab
- **前置条件**: 单个 tab
- **测试步骤**: 执行映射
- **验证**: `vim.fn.tabpagenr("$") == 2`
- **验证方式**: API 查询

### TC-KEY-075: `<tab>` 映射到 FlipPinnedTab
- **验证**: `vim.fn.maparg("<tab>", "n")` 包含 `FlipPinnedTab`
- **验证方式**: API 查询

### TC-KEY-076: `d<tab>` 关闭 tab
- **前置条件**: 2 个 tab
- **测试步骤**: 执行 `d<tab>`
- **验证**: tab 数减少
- **验证方式**: API 查询

### TC-KEY-077: `<C-tab>` 切换到下一个 tab
- **验证**: `vim.fn.maparg("<C-tab>", "n")` 包含 `tabnext`
- **验证方式**: API 查询

### TC-KEY-078: `<S-C-tab>` 切换到上一个 tab
- **验证**: `vim.fn.maparg("<S-C-tab>", "n")` 包含 `tabprev`
- **验证方式**: API 查询

### TC-KEY-079: `<leader>up` Pin/Unpin tab
- **验证**: `vim.fn.maparg("<leader>up", "n")` 非空（函数类型）
- **验证方式**: API 查询

### TC-KEY-080: `<leader>uP` 带参数 Pin tab
- **验证**: `vim.fn.maparg("<leader>uP", "n")` 包含 `PinTab`
- **验证方式**: API 查询

---

## 2.22 Neovide 透明度控制

### TC-KEY-081: `<leader>uT` 切换透明度
- **验证**: `vim.fn.maparg("<leader>uT", "n")` 包含 `NeovideTransparentToggle`
- **验证方式**: API 查询

---

## 2.23 Context 显示

### TC-KEY-082: `<C-G>` 显示 navic 位置
- **验证**: `vim.fn.maparg("<C-G>", "n")` 非空（函数类型）
- **验证方式**: API 查询

---

## 2.24 Debugging 映射（keymaps.lua 中定义的 debugging_keymaps 表）

### TC-KEY-083: `<leader>db` 切换断点
- **验证**: `vim.fn.maparg("<leader>db", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-084: `<leader>dB` 显示断点列表
- **验证**: `vim.fn.maparg("<leader>dB", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-085: `<leader>dc` 继续执行
- **验证**: `vim.fn.maparg("<leader>dc", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-086: `<leader>dC` 运行到光标处
- **验证**: `vim.fn.maparg("<leader>dC", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-087: `<leader>dW` 添加 watch（支持 visual）
- **验证**: `vim.fn.maparg("<leader>dW", "n")` 非空 且 `vim.fn.maparg("<leader>dW", "v")` 非空
- **验证方式**: API 查询

### TC-KEY-088: `<leader>dn` step over
- **验证**: `vim.fn.maparg("<leader>dn", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-089: `<leader>dN` 新调试会话
- **验证**: `vim.fn.maparg("<leader>dN", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-090: `<leader>ds` step into
- **验证**: `vim.fn.maparg("<leader>ds", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-091: `<leader>dS` 显示 sessions
- **验证**: `vim.fn.maparg("<leader>dS", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-092: `<leader>do` step out
- **验证**: `vim.fn.maparg("<leader>do", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-093: `<leader>du` 上移调用栈
- **验证**: `vim.fn.maparg("<leader>du", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-094: `<leader>dd` 下移调用栈
- **验证**: `vim.fn.maparg("<leader>dd", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-095: `<leader>dF` 显示 frames
- **验证**: `vim.fn.maparg("<leader>dF", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-096: `<leader>dp` hover
- **验证**: `vim.fn.maparg("<leader>dp", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-097: `<leader>dP` 显示 scopes
- **验证**: `vim.fn.maparg("<leader>dP", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-098: `<leader>dR` 重启调试
- **验证**: `vim.fn.maparg("<leader>dR", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-099: `<leader>d<c-c>` 暂停
- **验证**: `vim.fn.maparg("<leader>d<c-c>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-100: `<leader>dT` 切换 DapView
- **验证**: `vim.fn.maparg("<leader>dT", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-101: `<leader>dE` 断开并关闭调试
- **验证**: `vim.fn.maparg("<leader>dE", "n")` 非空
- **验证方式**: API 查询

---

## 2.25 Debugging 模式切换

### TC-KEY-102: `<leader>dD` 切换调试键映射模式
- **前置条件**: `vim.g.debugging_keymap == false`
- **测试步骤**: 执行 `<leader>dD`
- **验证**: `vim.g.debugging_keymap == true`
- **验证方式**: API 查询

### TC-KEY-103: 调试模式中 `b` 映射到断点切换
- **前置条件**: 执行了 `vim.g.nvim_dap_keymap()`
- **验证**: `vim.fn.maparg("b", "n")` 非空（映射到 dap.toggle_breakpoint）
- **验证方式**: API 查询

### TC-KEY-104: 调试模式中 `c` 映射到 continue
- **前置条件**: 调试模式开启
- **验证**: `vim.fn.maparg("c", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-105: 退出调试模式恢复原始映射
- **前置条件**: 开启调试模式后再关闭
- **测试步骤**: `vim.g.nvim_dap_keymap()` 然后 `vim.g.nvim_dap_upmap()`
- **验证**: `b` 键恢复到原始映射
- **验证方式**: API 查询

### TC-KEY-106: `<leader>DD` 启动通用调试
- **验证**: `vim.fn.maparg("<leader>DD", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-107: `<leader>Dt` 终止调试
- **验证**: `vim.fn.maparg("<leader>Dt", "n")` 包含 `DapTerminate`
- **验证方式**: API 查询

---

## 2.26 Cmd-映射（D-* 到 leader 映射）

### TC-KEY-108: `<D-a>` 映射到 AI 修改 (`<leader>ae`)
- **验证**: `vim.fn.maparg("<D-a>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-109: `<D-b>` 映射到 buffer 列表 (`<leader>bb`)
- **验证**: `vim.fn.maparg("<D-b>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-110: `<D-c>` 映射到 comment (`<leader>cm`)
- **验证**: `vim.fn.maparg("<D-c>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-111: `<D-D>` 映射到调试模式切换 (`<leader>dD`)
- **验证**: `vim.fn.maparg("<D-D>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-112: `<D-e>` 映射到文件浏览 (`<leader>fe`)
- **验证**: `vim.fn.maparg("<D-e>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-113: `<D-f>` 映射到文件查找 (`<leader>ff`)
- **验证**: `vim.fn.maparg("<D-f>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-114: `<D-g>` 映射到 git hunk preview (`<leader>hp`)
- **验证**: `vim.fn.maparg("<D-g>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-115: `<D-i>` 映射到消息历史 (`<leader>im`)
- **验证**: `vim.fn.maparg("<D-i>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-116: `<D-j>` 映射到 buffer 诊断 (`<leader>jj`)
- **验证**: `vim.fn.maparg("<D-j>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-117: `<D-k>` 映射到 keymaps 列表 (`<leader>sk`)
- **验证**: `vim.fn.maparg("<D-k>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-118: `<D-l>` 映射到任务输出 (`<leader>ll`)
- **验证**: `vim.fn.maparg("<D-l>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-119: `<D-n>` 创建新 buffer
- **验证**: `vim.fn.maparg("<D-n>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-120: `<D-o>` 映射到窗口最大化 (`<leader>wm`)
- **验证**: `vim.fn.maparg("<D-o>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-121: `<D-p>` 映射到命令历史 (`<leader>pp`)
- **验证**: `vim.fn.maparg("<D-p>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-122: `<D-r>` 映射到 LSP rename (`<leader>rn`)
- **验证**: `vim.fn.maparg("<D-r>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-123: `<D-s>` 映射到 symbols (`<leader>ss`)
- **验证**: `vim.fn.maparg("<D-s>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-124: `<D-t>` 映射到终端 (`<leader>tt`)
- **验证**: `vim.fn.maparg("<D-t>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-125: `<D-v>` 映射到粘贴 (`<leader>ps`)
- **验证**: `vim.fn.maparg("<D-v>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-126: `<D-w>` 映射到关闭 buffer (`<leader>bd`)
- **验证**: `vim.fn.maparg("<D-w>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-127: `<D-x>` 映射到水平分割 (`<leader>-`)
- **验证**: `vim.fn.maparg("<D-x>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-128: `<D-y>` 映射到 yanky (`<leader>yy`)
- **验证**: `vim.fn.maparg("<D-y>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-129: `<D-z>` 映射到 zoxide (`<leader>zz`)
- **验证**: `vim.fn.maparg("<D-z>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-130: `<D-/>` 映射到全局搜索 (`<leader>/`)
- **验证**: `vim.fn.maparg("<D-/>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-131: `<D-CR>` 映射到格式化 (`<leader><CR>`)
- **验证**: `vim.fn.maparg("<D-CR>", "n")` 非空
- **验证方式**: API 查询

### TC-KEY-132: D-* 映射在 insert 模式也工作
- **验证**: `vim.fn.maparg("<D-f>", "i")` 非空
- **验证方式**: API 查询

### TC-KEY-133: `no_insert_mode` 的映射不在 insert 模式注册
- **验证**: `vim.fn.maparg("<D-CR>", "i")` 为空（因为 `no_insert_mode = true`）
- **验证方式**: API 查询

### TC-KEY-134: `back_to_insert` 的映射在 insert 模式执行后回到 insert
- **验证**: 映射函数包含回到 insert 的逻辑
- **验证方式**: 检查映射描述/函数签名

---

**本模块测试用例总数: 134**
