# nvim-refine

A Neovim setup with extremely neat UI, optimized for productivity.

## Features

- **Dracula theme** with transparent floating windows and custom highlights
- **AI integration**: Copilot, Avante (Claude/DeepSeek), and inline code rewriting via gp.nvim
- **Debugging**: Full DAP setup with breakpoints, virtual text, and no-UI debug keymaps
- **Git**: Gitsigns, diffview, gitlinker, lazygit integration
- **Navigation**: Snacks.nvim picker with zoxide, bookmarks, and smart file finding
- **LSP**: Mason-managed language servers for Rust, Go, Python, C++, Lua, and more
- **Terminal**: Tmux-integrated floating terminal with layout management
- **Task runner**: Overseer.nvim for build/run tasks
- **Snippets**: LuaSnip with VSCode snippet support
- **Remote**: Neovide remote server support via Docker

## Installation

```bash
git clone https://github.com/Kailian-Jacy/nvim-refine \
    && cd nvim-refine \
    && chmod +x ./setup.sh \
    && ./setup.sh
```

### Install Modes

```bash
./setup.sh --full     # Full installation (default): all tools, fonts, LSPs
./setup.sh --minimal  # Core neovim only: config + treesitter build deps
./setup.sh --docker   # Optimized for containers: apt + binary downloads, no fonts
```

### Docker

```bash
docker build -t nvim-refine .
docker run --rm -it -p 9099:9099 nvim-refine
```

The Dockerfile auto-detects container environment and uses `apt` + direct binary downloads instead of Homebrew.

Then connect from Neovide or any Neovim client:
```bash
nvim --server localhost:9099 --remote-ui
```

### Package Manager Strategy

| Environment | Package Manager | Notes |
|---|---|---|
| macOS | Homebrew | Standard, uses pre-built bottles |
| Linux (user) | Homebrew | Cross-platform consistency |
| Linux (root/Docker) | apt + binaries | Homebrew refuses root; apt is faster in containers |

### Requirements

- Neovim 0.11+ (installed automatically by setup.sh)
- zsh (used as default shell)

## Configuration

Local customization goes in `config.nvim/lua/config/local.lua` (not tracked by git).
Copy from the template:

```bash
cp config.nvim/lua/config/local.template.lua config.nvim/lua/config/local.lua
```

## Key Mappings

Leader key: `Space`

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>ff` | n | Smart find files |
| `<leader>/` | n,v | Grep search |
| `<leader>fe` | n | File explorer |
| `<leader>zz` | n | Zoxide directory navigation |
| `<leader>tt` | n | Toggle floating terminal |
| `<leader>gg` | n | Lazygit |
| `<leader>aa` | n | Avante AI chat |
| `<leader>ae` | n,v | AI code rewrite |
| `<leader>DD` | n | Start debugging |
| `<leader>xb` | n | Toggle breakpoint |
| `<leader><CR>` | n,v | Format + lint + save |

See `config.nvim/lua/config/keymaps.lua` for the full keymap reference.

## License

See [LICENSE](config.nvim/LICENSE).
