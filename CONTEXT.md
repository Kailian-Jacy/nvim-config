# nvim-config 重构项目 — 背景与结论

> 生成时间: 2026-03-06 14:05 CST
> 用于 session reset 后恢复上下文

---

## 一、项目概况

- **仓库**: https://github.com/Kailian-Jacy/nvim-config
- **本地路径**: `/home/ubuntu/.openclaw/workspace-telegram/nvim-config/`
- **配置链接**: `~/.config/nvim` → `config.nvim/`
- **代码量**: ~8300 行 (7800 Lua + 250 VimScript + 260 Shell)
- **插件数**: 73 个 (47 个独立插件，50 启动加载 / 23 延迟加载)
- **架构**: lazy.nvim 插件管理器，非 LazyVim 框架，手动配置

---

## 二、已完成的工作

### 1. TUI 感知研究 ✅
- **报告**: `reports/01-tui-perception.md` (638 行)
- **GitHub Issue**: https://github.com/Kailian-Jacy/openclaw_notes/issues/2
- **结论**: 9 种方案全部实测验证。推荐 `nvim --headless` + `pynvim RPC` + `tmux capture-pane` 三者组合。大部分配置工作不需要视觉反馈。

### 2. 代码审查 ✅
- **报告**: `reports/02-code-review.md`
- **GitHub Issue**: https://github.com/Kailian-Jacy/openclaw_notes/issues/3
- **结论**: 发现 36 个问题 + 7 个真实 Bug

#### 7 个真实 Bug:
1. `vim.fn.has()` 返回值误用 → 所有平台被识别为 MACOS
2. `prebuild.sh` 嵌套同名函数
3. `FlipPinnedTab` 拼写错误 `last_lab` → `last_tab`
4. `bookmarks.nvim` 的 `enable` → `enabled` + 条件表达式错误
5. `RunScript` 超时逻辑 `or` → `and`
6. `SvnDiffShiftVersion` 覆盖 opts 对象
7. `string()` → `tostring()`

#### Top 5 架构问题:
1. **P1** `autocmds.lua` 1697 行上帝文件 → 拆分为 6-8 个模块
2. **P7** 键映射分散 5 处且冲突
3. **P17** 13+ 函数放在 `vim.g` 上 → 应改为 `lua/utils/` 模块
4. **P20** 零测试、零 CI/CD
5. **P25** 过多 `lazy = false` 影响启动速度

### 3. 环境搭建 ✅
- **报告**: `reports/03-environment-setup.md`
- **GitHub Issue**: https://github.com/Kailian-Jacy/openclaw_notes/issues/4
- **结论**: 环境准备就绪

#### 已安装:
- Neovim v0.11.6 (官方 release, `/opt/nvim-linux-x86_64`)
- 73 个插件全部安装，14 个 TreeSitter 解析器已编译
- Mason 工具 9 个: lua-language-server, stylua, bash-language-server, shellcheck, gopls, goimports, bash-debug-adapter, codelldb, dlv
- Rust 1.94.0 + rust-analyzer
- debugpy 1.8.20 (venv: `~/.local/share/nvim/debugpy-venv/`)
- TabNine v4.321.0
- CLI: rg, fd, fzf, lazygit, zoxide, tmux, sqlite3, gh, luarocks
- API Keys: DEEPSEEK_API_KEY + OPENROUTER_API_KEY 已配置

---

## 三、文件路径索引

```
nvim-config/
├── CONTEXT.md                          ← 本文件（reset 后读这个）
├── reports/
│   ├── 01-tui-perception.md            ← TUI 感知研究报告
│   ├── 02-code-review.md               ← 代码审查报告（36 问题 + 7 Bug）
│   └── 03-environment-setup.md         ← 环境搭建报告
├── config.nvim/                        ← Neovim 配置（已链接到 ~/.config/nvim）
│   ├── init.lua                        ← 入口 (46 行)
│   ├── lua/config/
│   │   ├── options.lua                 ← 选项 + 全局变量 (445 行)
│   │   ├── keymaps.lua                 ← 键映射 (885 行)
│   │   ├── autocmds.lua                ← 上帝文件 (1697 行) ← 重构重点
│   │   ├── lazy.lua                    ← lazy.nvim 引导 (43 行)
│   │   └── local.template.lua
│   └── lua/plugins/                    ← 17 个插件配置文件
├── setup.sh                            ← 安装脚本 (Homebrew)
├── prebuild.sh                         ← 过时脚本 (有 bug, 建议删除)
└── dockerfile
```

---

## 四、下一步建议

### 快速修复（30 分钟，7 项）:
1. 修复 `vim.fn.has()` bug (15min)
2. 删除重复 `cmp-tabnine` 声明 (5min)
3. `io.popen("nproc")` → `vim.uv.cpu_info()` (10min)
4. 补全 RTP 禁用列表 (10min)
5. 删除 `prebuild.sh` (5min)
6. 删除空文件 mark.lua/navigation.lua/remote.lua (5min)
7. 硬编码用户名 → 变量 (10min)

### 架构重构（按优先级）:
1. 🔴 拆分 `autocmds.lua` (4-6h)
2. 🔴 整理键映射冲突 (3-4h)
3. 🔴 `vim.g` 函数 → `lua/utils/` 模块 (3-4h)
4. 🔴 添加测试 + CI/CD (1-6h)
5. 🔴 优化懒加载策略 (3-4h)

---

## 五、工作方式备忘

### AI 调试 Neovim 的最佳方式:
- **语法检查**: `nvim --headless -c 'lua local ok,e = loadfile("file.lua"); print(ok and "OK" or e)' -c 'qa!'`
- **运行时检查**: `nvim --headless -c 'luafile file.lua' -c 'qa!' 2>&1`
- **RPC 深度调试**: tmux 中启动 `nvim --listen /tmp/nvim.sock`，用 pynvim 连接查询
- **UI 验证**: `tmux capture-pane -t <session> -p`
- **批量语法检查**: `nvim -l scripts/check-syntax.lua`

### GitHub Issue 交付:
- Repo: `Kailian-Jacy/openclaw_notes`
- Token: 见 MEMORY.md
- 已创建: #2 (TUI), #3 (代码审查), #4 (环境)
