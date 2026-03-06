# Test Plan Part 6: 测不到的部分 (Untestable Areas)

> 诚实报告无法通过 headless nvim API 测试或极难可靠测试的功能点

---

## 6.1 完全不可测试

### U-001: Neovide 特有功能
- **涉及**: 所有 `vim.g.neovide_*` 选项（透明度、动画、padding、blur）
- **原因**: Neovide 是独立的 GUI 前端，headless Neovim 不运行 Neovide 渲染引擎。选项可以查询但视觉效果无法验证。
- **覆盖范围**: TC-OPT-057~064 只验证值的设置，不验证视觉效果

### U-002: `<D-*>` (Cmd 键) 映射的实际触发
- **涉及**: 所有 `<D-*>` 映射（约 30 个）
- **原因**: `<D-*>` 键码是 macOS + Neovide 特有的，在 terminal/headless 中无法生成。只能验证映射存在，不能验证实际触发。
- **缓解**: 验证映射注册（maparg 查询）；对应的 `<leader>*` 映射可以测试

### U-003: GUI 字体渲染
- **涉及**: `vim.o.guifont` 相关（当前注释掉了）
- **原因**: headless 无 GUI 渲染

### U-004: Copilot 实际代码补全
- **涉及**: copilot.vim 的补全建议、Accept、Previous、Next
- **原因**: 需要实际的 Copilot 认证和网络连接，且补全结果不确定
- **缓解**: 可以验证映射存在和插件加载

### U-005: AI 补全（gp.nvim / Avante）
- **涉及**: Rewrite 命令、AI chat、模型调用
- **原因**: 依赖外部 API（OpenRouter、Deepseek 等），需要 API key 和网络
- **缓解**: 验证命令/映射存在

### U-006: Obsidian 应用集成
- **涉及**: ObsOpen 硬链接、ObsUnlink、ObsidianBridgeTelescopeCommand
- **原因**: 依赖 macOS 上安装的 Obsidian.app 和 iCloud vault 路径
- **缓解**: 命令存在性可测，实际功能需 macOS 环境

### U-007: LazyGit 交互
- **涉及**: `:Lazygit` 命令、`<leader>G`
- **原因**: 需要 lazygit 安装和 git 仓库环境，且是全屏终端 UI
- **缓解**: 命令存在性可测

### U-008: tmux 实际交互
- **涉及**: terminal.nvim 的 tmux session 创建、VimLeave 的 tmux detach
- **原因**: 需要 tmux 运行环境，且 headless nvim 不一定在 tmux 中
- **缓解**: 可以 mock tmux 环境或验证命令字符串

### U-009: SVN 操作（条件启用）
- **涉及**: SvnDiffThis、SvnDiffAll、SvnDiffShiftVersion 等
- **原因**: 需要 svn 工作目录和 svn 可执行文件，测试环境通常无 svn
- **缓解**: 可在有 svn 的环境中手动测试

### U-010: Clipboard 系统集成
- **涉及**: OSC52 同步、`"*y`、`"+p` 等
- **原因**: headless 模式无 GUI 剪贴板；OSC52 依赖终端模拟器支持
- **缓解**: 可以验证寄存器内容，但不能验证实际系统剪贴板同步

---

## 6.2 难以可靠测试（Flaky/Complex）

### U-011: Snacks Picker UI 交互
- **涉及**: 所有 Snacks.picker.* 调用的完整 UI 流程
- **原因**: picker 是浮动窗口 UI，需要模拟键入、选择、确认。虽然可以通过 API 打开 picker，但验证显示内容和选择结果需要复杂的模拟。
- **缓解**: 可以验证 picker 打开不报错；使用 RPC 发送键来测试基本流程

### U-012: 补全 (nvim-cmp) 交互流程
- **涉及**: Tab 键补全确认、Up/Down 选择、snippet 展开
- **原因**: cmp 补全菜单的出现取决于 LSP 状态、buffer 内容、typing 速度。难以在 headless 中可靠触发。
- **缓解**: 可以程序化模拟：设置 buffer 内容、触发补全源、检查 cmp.visible()

### U-013: LSP 相关功能
- **涉及**: gd (go to definition), gr (references), ga (code action), rename 等
- **原因**: 需要 LSP server 启动并分析代码，启动时间不确定
- **缓解**: 可以等待 LSP attach 后测试，但需要安装 LSP server 且等待初始化

### U-014: Telescope 和 DAP Telescope 集成
- **涉及**: vimrc.vim 中的 Telescope dap commands 等映射
- **原因**: 需要 telescope-dap 插件和 dap session
- **缓解**: 验证映射存在

### U-015: 终端自动进入 insert 模式
- **涉及**: WinEnter + TermOpen + startinsert
- **原因**: 在 headless 模式中 terminal buffer 行为可能不同
- **缓解**: 可以检查 autocmd 注册

### U-016: visual-surround 在 V 模式的行为分叉
- **涉及**: `<` 和 `>` 在 visual vs visual-line 中的不同行为
- **原因**: expr 映射 + 模式检测 + vim.schedule，时序敏感
- **缓解**: 分别测试两种模式下的行为

### U-017: DAP session 生命周期
- **涉及**: dap listeners、debugging_status 状态机
- **原因**: 需要实际启动调试会话（编译、运行、附加），每种语言配置不同
- **缓解**: 可以使用 lua 调试（osv）做最简单的端到端测试

### U-018: auto-save 触发
- **涉及**: InsertLeave、TextChanged 后的自动保存
- **原因**: 时序依赖（debounce），且需要已保存的文件
- **缓解**: 可以模拟事件并检查文件修改时间

### U-019: 行移动后的 visual 选择保持
- **涉及**: `<M-j>` 和 `<M-k>` 在 visual 模式保持选择
- **原因**: gv 恢复选择和 mode 检测的时序问题
- **缓解**: 可以通过 feedkeys + getpos 验证

### U-020: Scrollbar 视觉选择标记
- **涉及**: scrollbar lastjump handler 在 visual 模式显示选择范围
- **原因**: 需要 scrollbar 渲染和 visual 模式同步
- **缓解**: 验证 handler 注册

---

## 6.3 环境依赖的条件测试

### U-021: 语言模块条件启用
- **涉及**: modules.rust/go/python/cpp 的自动检测
- **原因**: 依赖测试环境安装了哪些工具链
- **策略**: 动态跳过不满足条件的测试，报告跳过原因

### U-022: SQLite 依赖的功能
- **涉及**: bookmarks（sqlite 存储）、yanky（sqlite 存储）
- **原因**: 需要 sqlite3 可执行文件
- **策略**: 检测 sqlite3 后才运行相关测试

### U-023: Mason 包安装
- **涉及**: MasonInstallAll 的实际安装
- **原因**: 需要网络，安装耗时长
- **策略**: 只验证命令存在和配置正确

---

## 6.4 平台特定

### U-024: macOS 特有路径和功能
- **涉及**: Obsidian vault 路径、Neovide.app、VSCode snippet 路径
- **原因**: 硬编码 macOS 路径
- **策略**: 在非 macOS 环境跳过

### U-025: `pstree` 命令依赖（tmux PID 获取）
- **涉及**: `vim.g.__tmux_get_current_attached_cliend_pid`
- **原因**: 使用 pstree 命令，不同系统参数可能不同
- **策略**: 平台检测后跳过

---

## 6.5 测试可行性总结

| 类别 | 测试用例数 | 可通过 API 测试 | 需要 UI/tmux | 完全不可测 |
|------|-----------|----------------|-------------|-----------|
| Options | 80 | 78 | 0 | 2 (Neovide 视觉) |
| Keymaps | 134 | 104 | 30 (D-* 触发) | 0 |
| Autocmds/Commands | 125 | 110 | 10 | 5 |
| Plugins | 179 | 140 | 25 | 14 |
| E2E Integration | 50 | 35 | 10 | 5 |
| **总计** | **568** | **467 (82%)** | **75 (13%)** | **26 (5%)** |

> **结论**: 约 82% 的测试可以通过 `nvim --headless` + Lua API 完全自动化；
> 13% 需要 tmux capture-pane 或特殊环境；5% 受限于平台/网络/GUI 无法自动测试。

---

## 6.6 推荐的测试分层

1. **第一层 (必须自动化)**: Options 查询、Keymap 存在性、Command 存在性 — ~300 个
2. **第二层 (应该自动化)**: 功能行为测试（buffer 操作、行移动、tab 管理等）— ~170 个  
3. **第三层 (手动/半自动)**: UI 交互（picker、补全、LSP）— ~75 个
4. **第四层 (跳过/标记)**: Neovide/macOS/网络依赖 — ~26 个
