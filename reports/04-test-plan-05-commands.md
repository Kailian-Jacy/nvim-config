# Test Plan Part 5: End-to-End Integration & Behavioral Tests

> 本节聚焦跨模块的端到端行为测试，验证多个组件协同工作

---

## 5.1 启动流程集成

### TC-E2E-001: 完整启动无错误
- **测试步骤**: `nvim --headless +"lua vim.defer_fn(function() vim.cmd('qa!') end, 5000)"`
- **验证**: 退出码为 0，无 ERROR 级别通知
- **验证方式**: 退出码 + 日志检查

### TC-E2E-002: 启动后所有插件加载
- **测试步骤**: 启动后执行 `require("lazy").stats()`
- **验证**: loaded 数量接近 73（已安装插件数）
- **验证方式**: API 查询

### TC-E2E-003: 加载顺序正确（vimrc → options → plugins → autocmds → keymaps）
- **前置条件**: 在各模块设置时间戳变量
- **验证**: 时间戳顺序正确
- **验证方式**: API 查询

---

## 5.2 Tab 生命周期

### TC-E2E-004: 创建 tab → pin → flip → unpin 完整流程
- **测试步骤**:
  1. `tabnew` 创建第二个 tab
  2. `:PinTab TestTab` 固定当前 tab
  3. 切换到另一个 tab
  4. `:FlipPinnedTab` 跳回
  5. `:UnpinTab` 取消固定
- **验证**: 每一步状态正确
- **验证方式**: API 查询

### TC-E2E-005: 关闭固定 tab 自动 unpin
- **测试步骤**: pin tab 1，关闭 tab 1
- **验证**: `vim.g.pinned_tab == nil`
- **验证方式**: API 查询

### TC-E2E-006: Tabline 显示固定标记
- **前置条件**: pin tab
- **验证**: `Tabline()` 返回字符串包含 `vim.g.pinned_tab_marker`
- **验证方式**: API 查询

---

## 5.3 Terminal 集成

### TC-E2E-007: 终端浮动 → 右侧 → 下方 → 重置流程
- **测试步骤**:
  1. `<leader>tt` 打开浮动终端
  2. `<C-S-l>` 移到右侧
  3. `<C-S-j>` 移到下方
  4. `<C-BS>` 重置
- **验证**: 每步窗口布局正确
- **验证方式**: API 查询窗口配置

### TC-E2E-008: 终端中方向键跳转到 nvim 窗口
- **前置条件**: 右侧分割有终端，左侧有编辑 buffer
- **测试步骤**: 在终端中 `<C-H>`
- **验证**: 焦点切到左侧编辑窗口
- **验证方式**: API 查询当前窗口

---

## 5.4 Buffer 管理

### TC-E2E-009: buffer 跳转历史（H/L）
- **测试步骤**:
  1. 打开 file1
  2. 打开 file2
  3. 按 `H`
- **验证**: 回到 file1
- **验证方式**: API 查询当前 buffer

### TC-E2E-010: buffer 关闭但保留窗口
- **前置条件**: 两个窗口显示不同 buffer
- **测试步骤**: `<leader>bd`
- **验证**: 窗口保留，显示另一个 buffer
- **验证方式**: API 查询

---

## 5.5 ThrowAndReveal 集成

### TC-E2E-011: ThrowAndReveal 到右侧新窗口
- **前置条件**: 单窗口打开 file A
- **测试步骤**: `:ThrowAndReveal l`
- **验证**: file A 在右侧，左侧回到历史 buffer，焦点在右侧
- **验证方式**: API 查询

### TC-E2E-012: ThrowAndReveal 到已有方向窗口
- **前置条件**: 左右两窗口
- **测试步骤**: 在左窗口 `:ThrowAndReveal l`
- **验证**: buffer 移到右侧已有窗口，不创建新窗口
- **验证方式**: API 查询

---

## 5.6 Debugging 模式集成

### TC-E2E-013: 调试模式开启/关闭键映射切换
- **测试步骤**:
  1. `<leader>dD` 开启调试模式
  2. 检查 `b` 键映射到 breakpoint
  3. `<leader>dD` 关闭调试模式
  4. 检查 `b` 键恢复
- **验证**: 键映射正确切换
- **验证方式**: API 查询

### TC-E2E-014: debugging_status 在 DAP 事件中正确变化
- **验证**: 检查 dap listeners 链条：initialized → stopped → continued → terminated
- **验证方式**: 配置检查

### TC-E2E-015: lualine 在调试时显示调试信息
- **前置条件**: debugging_keymap = true
- **验证**: lualine 状态栏包含调试标记
- **验证方式**: 功能测试

---

## 5.7 格式化集成

### TC-E2E-016: ConformFormat 在 restrict 模式下只格式化小范围
- **前置条件**: `vim.g.format_behavior.default == "restrict"`，在大函数内
- **测试步骤**: `:ConformFormat`
- **验证**: 当树节点行数 > max_silent_format_line_cnt 时跳过
- **验证方式**: 功能测试

### TC-E2E-017: ConformFormat 在 visual 模式格式化选中区域
- **前置条件**: 选中部分代码
- **测试步骤**: `:ConformFormat`
- **验证**: 只有选中区域被格式化
- **验证方式**: buffer 内容比较

### TC-E2E-018: `<leader><CR>` 格式化 + lint + 保存 + scrollbar 刷新
- **前置条件**: 打开有已保存的文件
- **测试步骤**: 执行 `<leader><CR>`
- **验证**: conform.format 和 lint.try_lint 都被调用
- **验证方式**: 功能测试

---

## 5.8 Quickfix 集成

### TC-E2E-019: quickfix 中 dd 删除条目
- **前置条件**: quickfix 列表有 3 项
- **测试步骤**: `:copen`，在第 2 项按 `dd`
- **验证**: quickfix 列表变为 2 项，第 2 项被删除
- **验证方式**: `vim.fn.getqflist()` 长度检查

### TC-E2E-020: quickfix 中 visual d 删除多条
- **前置条件**: quickfix 列表有 5 项
- **测试步骤**: 选中 2-4 项，按 `d`
- **验证**: quickfix 列表变为 2 项
- **验证方式**: `vim.fn.getqflist()` 长度检查

### TC-E2E-021: Qnext/Qprev 循环导航
- **前置条件**: quickfix 列表有 3 项
- **测试步骤**: 从第 3 项 `:Qnext`
- **验证**: 跳到第 1 项
- **验证方式**: API 查询光标位置

---

## 5.9 CopyFilePath 集成

### TC-E2E-022: CopyFilePath full 端到端
- **前置条件**: `cd /tmp && nvim test.txt`
- **测试步骤**: `:CopyFilePath full`
- **验证**: `vim.fn.getreg("*") == "/tmp/test.txt"`
- **验证方式**: API 查询

### TC-E2E-023: CopyFilePath relative 去除 cwd 前缀
- **前置条件**: cwd=/tmp，打开 /tmp/a/b.txt
- **测试步骤**: `:CopyFilePath relative`
- **验证**: `vim.fn.getreg("*") == "a/b.txt"`
- **验证方式**: API 查询

---

## 5.10 Script Runner 集成

### TC-E2E-024: Lua script 在 neovim 内运行
- **前置条件**: lua 文件内容 `return vim.version().minor`
- **测试步骤**: `:RunScript`
- **验证**: 输出为 nvim 版本号
- **验证方式**: 通知检查

### TC-E2E-025: SetBufRunner 覆盖后 RunScript 使用新 runner
- **前置条件**: lua 文件，`:SetBufRunner "echo overridden"`
- **测试步骤**: `:RunScript`
- **验证**: 输出包含 "overridden"
- **验证方式**: 通知检查

### TC-E2E-026: `<C-c>` 中断正在运行的脚本
- **前置条件**: 运行长时间脚本
- **测试步骤**: `<C-c>`
- **验证**: `vim.g._current_runner == nil`
- **验证方式**: API 查询

---

## 5.11 Yank 集成

### TC-E2E-027: TextYankPost 高亮闪烁
- **测试步骤**: yank 一行
- **验证**: highlight_yank autocmd 触发
- **验证方式**: autocmd 存在性检查

### TC-E2E-028: TextYankPost yanky ring 过滤
- **前置条件**: yanky_ring_accept_length=10
- **测试步骤**: yank 5 个字符
- **验证**: 不进入 yanky ring
- **验证方式**: yanky history 检查

### TC-E2E-029: OSC52 clipboard sync
- **测试步骤**: yank 操作
- **验证**: TextYankPost 中 osc52 回调被调用
- **验证方式**: autocmd 检查

---

## 5.12 Macro 录制集成

### TC-E2E-030: 录制开始时 recording_status 变 true
- **测试步骤**: `qq`
- **验证**: `vim.g.recording_status == true`
- **验证方式**: API 查询

### TC-E2E-031: 录制结束时 recording_status 变 false
- **测试步骤**: `q`
- **验证**: `vim.g.recording_status == false`
- **验证方式**: API 查询

### TC-E2E-032: lualine 在录制时显示 'q' 标记
- **验证**: lualine z 段在录制时包含 `q`
- **验证方式**: 功能测试

---

## 5.13 Snippet 集成

### TC-E2E-033: SnipEdit → SnipLoad 流程
- **测试步骤**: `:SnipEdit` → 编辑 → `:SnipLoad`
- **验证**: snippet 被重新加载
- **验证方式**: luasnip.get_snippets 检查

### TC-E2E-034: SnipPick 打开 picker
- **测试步骤**: `:SnipPick`
- **验证**: Snacks picker 打开，显示 snippets 列表
- **验证方式**: 功能测试（需要 UI 交互）

---

## 5.14 Bookmark 集成

### TC-E2E-035: 创建书签 → 查看 → 删除 流程
- **测试步骤**:
  1. `m` → 输入名称
  2. `'` 查看列表
  3. `<leader>md` 删除
- **验证**: 书签正确创建和删除
- **验证方式**: 功能测试

### TC-E2E-036: BookmarkGrepMarkedFiles 在标记文件中搜索
- **前置条件**: 已标记多个文件
- **测试步骤**: `:BookmarkGrepMarkedFiles`
- **验证**: grep picker 打开，限定在标记文件中
- **验证方式**: 功能测试

---

## 5.15 窗口最大化集成

### TC-E2E-037: 最大化 → 恢复流程
- **前置条件**: 两个等大窗口
- **测试步骤**: `<leader>wm` → 检查 → `<leader>wm`
- **验证**: 第一次最大化当前窗口，第二次恢复等分
- **验证方式**: 窗口尺寸 API 查询

### TC-E2E-038: lualine 在最大化时显示 'm' 标记
- **前置条件**: 窗口最大化
- **验证**: lualine z 段包含 `m`
- **验证方式**: 功能测试

---

## 5.16 VimEnter/VimLeave 集成

### TC-E2E-039: VimLeavePre 保存 LAST_WORKING_DIRECTORY
- **验证**: VimLeavePre autocmd 将 cwd 保存到 vim.g.LAST_WORKING_DIRECTORY
- **验证方式**: 触发事件后检查

### TC-E2E-040: VimLeave 尝试 detach tmux
- **验证**: VimLeave autocmd 存在 tmux detach 逻辑
- **验证方式**: autocmd 检查

---

## 5.17 Snacks Picker 自定义 Action

### TC-E2E-041: picker 中 `<c-t>` 在新 tab 打开
- **验证**: snacks picker 配置中 new_tab_here action 存在
- **验证方式**: 配置检查

### TC-E2E-042: picker 中 `<c-/>` 搜索选中文件
- **验证**: search_from_selected action 存在
- **验证方式**: 配置检查

### TC-E2E-043: picker 中 maximize action 工作
- **验证**: maximize action 存在且切换 fullscreen
- **验证方式**: 配置检查

### TC-E2E-044: zoxide picker 中 lcd 和 tcd 动作
- **验证**: zoxide_lcd 和 zoxide_tcd actions 存在
- **验证方式**: 配置检查

### TC-E2E-045: explorer 中 `<d-cr>` tcd 到目录
- **验证**: tcd_to_item action 存在
- **验证方式**: 配置检查

### TC-E2E-046: command_history picker 中 modify 和 execute 动作
- **验证**: modify 和 execute_without_modification actions 存在
- **验证方式**: 配置检查

---

## 5.18 Line Move 集成

### TC-E2E-047: `<M-j>` 行下移功能验证
- **前置条件**: buffer: "line1\nline2\nline3"，光标在 line1
- **测试步骤**: `<M-j>`
- **验证**: buffer 变为 "line2\nline1\nline3"
- **验证方式**: `nvim_buf_get_lines` 检查

### TC-E2E-048: `<M-k>` 行上移功能验证
- **前置条件**: buffer: "line1\nline2\nline3"，光标在 line2
- **测试步骤**: `<M-k>`
- **验证**: buffer 变为 "line2\nline1\nline3"
- **验证方式**: `nvim_buf_get_lines` 检查

---

## 5.19 Visual Till Brackets 集成

### TC-E2E-049: `[` 键在有 `[` 的行中跳到 `[` 前
- **前置条件**: buffer: "hello [world]"，光标在 h
- **测试步骤**: 按 `[`
- **验证**: 光标在 `[` 之前的空格上
- **验证方式**: API 查询光标列

### TC-E2E-050: `d[` 删除到 `[` 之前
- **前置条件**: buffer: "hello [world]"，光标在 h
- **测试步骤**: 按 `d[`
- **验证**: buffer 变为 "[world]"
- **验证方式**: `nvim_buf_get_lines` 检查

---

**本模块测试用例总数: 50**
