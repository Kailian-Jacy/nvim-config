# Neovim Config 端到端功能测试覆盖计划 — 汇总索引

## 项目概况
- **代码量**: ~8300 行 (7800 Lua + 250 VimScript + 260 Shell)
- **插件数**: 73 个
- **配置文件**: 21 个 (1 init.lua + 1 vimrc.vim + 1 lazy.lua + 3 config/*.lua + 17 plugins/*.lua)

## 测试计划文件索引

| 文件 | 模块 | 测试用例数 |
|------|------|-----------|
| [04-test-plan-01-options.md](04-test-plan-01-options.md) | Options & Global Settings | 80 |
| [04-test-plan-02-keymaps.md](04-test-plan-02-keymaps.md) | Keymaps | 134 |
| [04-test-plan-03-autocmds.md](04-test-plan-03-autocmds.md) | Autocmds & Custom Commands | 125 |
| [04-test-plan-04-plugins.md](04-test-plan-04-plugins.md) | Plugin Configurations | 179 |
| [04-test-plan-05-commands.md](04-test-plan-05-commands.md) | E2E Integration | 50 |
| [04-test-plan-06-untestable.md](04-test-plan-06-untestable.md) | Untestable Areas | 25 items |
| **总计** | | **568 test cases** |

## 测试用例编号分配

| 前缀 | 范围 | 描述 |
|------|------|------|
| TC-INIT-* | 001-009 | init.lua 启动加载 |
| TC-VIM-* | 001-030 | vimrc.vim 选项 |
| TC-OPT-* | 001-080 | options.lua 设置 |
| TC-KEY-* | 001-134 | 键映射 |
| TC-CMD-* | 001-125 | 自定义命令和 autocmd |
| TC-PLG-* | 001-179 | 插件配置 |
| TC-E2E-* | 001-050 | 端到端集成 |
| U-* | 001-025 | 不可测试项 |

## 测试方法论

### 主要测试方式
1. **nvim --headless + luafile**: 约 82% 的测试
   ```bash
   nvim --headless -u config.nvim/init.lua +"luafile test_options.lua" +qa
   ```

2. **pynvim RPC**: 复杂交互测试
   ```python
   import pynvim
   nvim = pynvim.attach('child', argv=['nvim', '--embed', '-u', 'config.nvim/init.lua'])
   ```

3. **tmux capture-pane**: UI 验证（约 13%）
   ```bash
   tmux capture-pane -p -t target_session
   ```

### 测试原则
- **幂等性**: 每个测试不依赖其他测试的状态
- **不依赖实现**: 只测试暴露给用户的行为
- **条件跳过**: 依赖特定工具/平台的测试在条件不满足时自动跳过

### 验证类型
- **API 查询** (82%): `vim.o.xxx`, `vim.g.xxx`, `vim.fn.maparg()`, `vim.fn.exists()`
- **功能测试** (13%): 设置 buffer → 执行操作 → 检查结果
- **配置检查** (5%): 检查插件配置表的内容

## 覆盖范围详情

### 按源文件覆盖

| 源文件 | 行数 | 提取功能点 | 测试用例数 |
|--------|------|-----------|-----------|
| init.lua | 46 | 9 | 9 |
| vimrc.vim | ~250 | 30 | 30 |
| options.lua | ~290 | 80 | 80 |
| keymaps.lua | 885 | 134 | 134 |
| autocmds.lua | 1697 | 125 | 125 |
| plugins/editor.lua | ~300 | 30 | 30 |
| plugins/lsp.lua | ~350 | 27 | 27 |
| plugins/cmp.lua | ~300 | 12 | 12 |
| plugins/git.lua | ~200 | 12 | 12 |
| plugins/debug.lua | ~280 | 12 | 12 |
| plugins/theme.lua | ~500 | 18 | 18 |
| plugins/miscellaneous.lua | ~700 | 30 | 30 |
| plugins/ai.lua | ~350 | 5 | 5 |
| plugins/rust.lua | ~80 | 5 | 5 |
| plugins/go.lua | ~20 | 1 | 1 |
| plugins/python.lua | ~70 | 3 | 3 |
| plugins/hex.lua | ~10 | 1 | 1 |
| plugins/obsidian.lua | ~50 | 1 | 1 |
| plugins/task.lua | ~120 | 5 | 5 |
| plugins/mark.lua | 3 | 0 | 0 |
| plugins/remote.lua | ~3 (全注释) | 0 | 0 |
| plugins/navigation.lua | ~120 (全注释) | 0 | 0 |

### 按功能类别覆盖

| 功能类别 | 测试用例数 |
|---------|-----------|
| Vim/Neovim 选项 | 110 |
| 键映射存在性 | 90 |
| 键映射行为 | 44 |
| 自定义命令存在性 | 55 |
| 自定义命令行为 | 40 |
| Autocmd 注册 | 20 |
| Autocmd 行为 | 30 |
| 插件加载 | 30 |
| 插件配置 | 50 |
| 端到端集成 | 50 |
| 全局函数/变量 | 49 |

## 自动化可行性

| 层级 | 描述 | 数量 | 占比 |
|------|------|------|------|
| L1 自动化 | API 查询（选项、映射、命令存在性） | ~300 | 53% |
| L2 自动化 | 功能行为（buffer 操作、行移动等） | ~170 | 30% |
| L3 半自动 | UI 交互（picker、补全、LSP） | ~75 | 13% |
| L4 跳过 | 环境/平台依赖 | ~26 | 4% |

## 推荐的实施顺序

1. **Phase 1**: L1 自动化测试 (1-2 天) — 快速获得高覆盖
2. **Phase 2**: L2 功能行为测试 (2-3 天) — 重点测试核心功能
3. **Phase 3**: L3 半自动测试框架 (3-5 天) — 有 tmux 支持的集成测试
4. **Phase 4**: 持续维护 — 新功能同步添加测试

## 测试运行环境要求

### 最低要求
- Neovim 0.10+
- git（插件安装）
- Node.js（copilot 相关）
- 网络访问（首次插件安装）

### 完整测试
- Python 3 + pynvim（RPC 测试）
- tmux（UI 测试）
- sqlite3（bookmarks/yanky 测试）
- 各语言工具链（条件模块测试）
