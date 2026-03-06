# 环境准备报告

**日期**: 2026-03-06
**系统**: Ubuntu 24.04 LTS (Noble Numbat) / Linux 6.8.0-71-generic x86_64

## 1. 已安装工具版本

### 核心工具
| 工具 | 版本 | 安装方式 |
|------|------|----------|
| Neovim | v0.11.6 (LuaJIT 2.1) | 官方 release tarball → `/opt/nvim-linux-x86_64` |
| GCC / G++ | 13.3.0 | apt (系统自带) |
| Node.js | v22.22.0 | apt (系统自带) |
| npm | 10.9.4 | apt (系统自带) |
| Python3 | 3.12.3 | apt (系统自带) |
| Go | 1.22.2 | apt (系统自带) |
| Git | 2.43.0 | apt (系统自带) |
| CMake | 3.28.3 | apt (系统自带) |
| Make | 4.3 | apt (系统自带) |

### CLI 工具
| 工具 | 版本 | 安装方式 |
|------|------|----------|
| ripgrep (rg) | 14.1.0 | apt |
| fd (fdfind) | 9.0.0 | apt + symlink `/usr/local/bin/fd` |
| fzf | 0.44.1 | apt |
| lazygit | 0.59.0 | GitHub release binary |
| zoxide | 0.9.9 | 官方 install.sh → `~/.local/bin` |
| tmux | 3.4 | apt (系统自带) |
| sqlite3 | 3.45.1 | apt |
| gh (GitHub CLI) | 2.87.3 | GitHub release binary |
| lua5.4 | 5.4.6 | apt |
| luarocks | 3.8.0 | apt |
| xsel | 1.2.1 | apt |
| unzip / zip | 系统版本 | apt |

### npm 全局包
| 包 | 用途 |
|----|------|
| vscode-langservers-extracted | HTML/CSS/JSON LSP |

## 2. Neovim 配置部署

- **配置源**: `/home/ubuntu/.openclaw/workspace-telegram/nvim-config/config.nvim/`
- **符号链接**: `~/.config/nvim` → 上述路径
- **插件管理器**: lazy.nvim (自动 bootstrap)
- **插件数量**: 73 个 (50 个启动加载, 23 个延迟加载)
- **TreeSitter 解析器**: 14 个 (bash, c, cpp, css, go, html, javascript, json, lua, python, rust, toml, typescript, yaml)

## 3. 已知问题及处理

### 3.1 启动时的警告（非阻塞）

| 警告 | 原因 | 严重性 |
|------|------|--------|
| `OpenDebugAD7 is not installed` | 未安装 C/C++ 调试适配器 (Mason) | 低 - 仅影响 C/C++ 调试 |
| `codelldb is not installed` | 未安装 Rust/C++ 调试适配器 (Mason) | 低 - 仅影响 Rust 调试 |
| `gopls is not installed` | 未安装 Go LSP (Mason) | 低 - 仅影响 Go 调试配置 |
| `bash-debug-adapter is not installed` | 未安装 Bash 调试适配器 (Mason) | 低 - 仅影响 Bash 调试 |
| `cmp-tabnine: Cannot find installed TabNine` | TabNine AI 补全未安装 | 低 - 可选 AI 功能 |
| `tmux detach` shell error | 无 tmux 会话运行 | 无影响 - autocmd 中的正常回退 |

### 3.2 安装过程中遇到的问题

| 问题 | 解决方案 |
|------|----------|
| `nvim-linux64.tar.gz` 文件名已改为 `nvim-linux-x86_64.tar.gz` | 使用新文件名下载 |
| apt 安装 gh 时 hang | 改用 GitHub release 直接下载二进制 |
| `fd` 命令名为 `fdfind` (Ubuntu) | 创建 `/usr/local/bin/fd` → `fdfind` 软链接 |
| npm 全局安装权限问题 | 使用 `sudo npm i -g` |

## 4. 环境模块自动检测状态

配置中的 `options.lua` 会自动检测可执行文件来启用模块：

| 模块 | 状态 | 原因 |
|------|------|------|
| rust | ❌ 未启用 | `rustc` 未安装 |
| go | ✅ 已启用 | `go` 已安装 |
| python | ✅ 已启用 | `python3` 已安装 |
| cpp | ✅ 已启用 | `gcc` 已安装 |
| copilot | ✅ 已启用 | `node` 已安装 |
| bookmarks | ✅ 已启用 | `sqlite3` 已安装 |
| svn | ❌ 未启用 | `svn` 未安装 |

## 5. 与 setup.sh 的差异

原始 `setup.sh` 使用 Homebrew (linuxbrew) 安装所有依赖。本次环境搭建**跳过了 Homebrew**，使用以下替代方案：
- apt 安装系统包 (ripgrep, fd-find, fzf, lua5.4, luarocks, sqlite3, xsel, zip)
- GitHub release 二进制安装 (lazygit, gh, neovim)
- 官方安装脚本 (zoxide)

这避免了 Homebrew 的编译开销，且所有工具功能等价。

## 6. 未部署的可选组件

以下组件不是必需的，按需安装：

| 组件 | 用途 | 安装方式 |
|------|------|----------|
| Mason 工具 (LSPs/formatters/linters) | 语言服务器、调试器 | `:MasonToolsInstall` 或 `:Mason` 手动安装 |
| TabNine | AI 代码补全 | 运行 cmp-tabnine 的 install.sh |
| Rust (rustc, cargo) | Rust 开发支持 | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Nerd Fonts | 图标显示 | 复制字体文件到 `~/.local/share/fonts/` |
| Copilot 登录 | GitHub Copilot | `:Copilot auth` |
| API Keys | AI 功能 (gp.nvim 等) | 设置 `OPENROUTER_API_KEY` / `DEEPSEEK_API_KEY` 环境变量 |

## 7. 需要人工决策的事项

1. **API Keys**: 如需 AI 功能 (gp.nvim, avante 等)，需手动设置 `OPENROUTER_API_KEY` 和 `DEEPSEEK_API_KEY` 环境变量
2. **Mason LSP 安装**: 可运行 `:MasonToolsInstall` 安装项目配置的所有 LSP，但这需要较长时间下载
3. **TabNine**: 如需 TabNine 补全，需手动运行其安装脚本
4. **Rust 工具链**: 如需 Rust 支持，需安装 rustup
5. **Copilot 认证**: 如需 GitHub Copilot，需在 Neovim 中运行 `:Copilot auth`

## 8. 当前环境限制

- **无 GUI**: 服务器环境，无法使用 Neovide 等图形化前端
- **无 X11 Display**: xsel 已安装但无法工作（无显示服务器），剪贴板功能受限
- **无 Homebrew**: 未安装 Homebrew，后续如需 setup.sh 中的某些特定版本工具需手动处理
- **Neovim 远程模式**: 可通过 `nvim --headless --listen 0.0.0.0:9099` 启动远程服务器，配合 Neovide 连接

## 9. 结论

✅ **环境准备就绪**。Neovim v0.11.6 已安装，73 个插件全部安装成功（50 个立即加载），14 个 TreeSitter 解析器已编译。配置能够正常加载和运行，所有启动警告均为非关键的可选组件缺失。环境可用于代码重构分析工作。
