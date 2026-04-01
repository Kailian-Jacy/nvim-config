# Dual-Version Neovim: Original + nixCats Side-by-Side

## Overview

This project supports running **two fully isolated Neovim instances** on the same machine:

| Version | Command | Config | Plugin Management |
|---------|---------|--------|-------------------|
| **Original** | `nvim` | `~/.config/nvim/` | lazy.nvim (Lua) |
| **nixCats** | `nvim-nix` | `~/.config/nvim-nix/` | Nix + nixCats |

### Why?

- **Zero-risk migration**: Try nixCats without touching your working setup
- **Gradual adoption**: Move plugins one at a time, keep a fallback
- **Different use cases**: Use original for quick edits, nixCats for full IDE
- **Reproducibility**: nixCats config is declarative and portable via Nix

### How It Works

Neovim's `NVIM_APPNAME` environment variable controls which set of directories it uses. By default, `NVIM_APPNAME` is `nvim`. Setting it to `nvim-nix` makes Neovim use completely separate directories for config, data, state, cache, and shada files.

The nixCats build sets `NVIM_APPNAME = "nvim-nix"` and installs as a separate package named `nvim-nix`, so it never conflicts with a system-installed Neovim.

## Directory Structure

### Linux

| Purpose | Original (`nvim`) | nixCats (`nvim-nix`) |
|---------|-------------------|----------------------|
| Config | `~/.config/nvim/` | `~/.config/nvim-nix/` |
| Data | `~/.local/share/nvim/` | `~/.local/share/nvim-nix/` |
| State | `~/.local/state/nvim/` | `~/.local/state/nvim-nix/` |
| Cache | `~/.cache/nvim/` | `~/.cache/nvim-nix/` |
| ShaDa | `~/.local/state/nvim/shada/` | `~/.local/state/nvim-nix/shada/` |
| Plugins | `~/.local/share/nvim/lazy/` | Managed by Nix store |

### macOS

| Purpose | Original (`nvim`) | nixCats (`nvim-nix`) |
|---------|-------------------|----------------------|
| Config | `~/.config/nvim/` | `~/.config/nvim-nix/` |
| Data | `~/.local/share/nvim/` | `~/.local/share/nvim-nix/` |
| State | `~/.local/state/nvim/` | `~/.local/state/nvim-nix/` |
| Cache | `~/Library/Caches/nvim/` | `~/Library/Caches/nvim-nix/` |
| ShaDa | `~/.local/state/nvim/shada/` | `~/.local/state/nvim-nix/shada/` |
| Plugins | `~/.local/share/nvim/lazy/` | Managed by Nix store |

> **Note**: macOS uses `~/Library/Caches/` instead of `~/.cache/` by default. You can override this by setting `XDG_CACHE_HOME`.

## Installation

### Prerequisites

- [Nix package manager](https://nixos.org/download) with flakes enabled
- Add to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`:
  ```
  experimental-features = nix-command flakes
  ```

### Option 1: Try without installing

```bash
# Run nixCats neovim directly (downloads and caches automatically)
nix run github:Kailian-Jacy/nvim-config#nvim-nix

# Open a specific file
nix run github:Kailian-Jacy/nvim-config#nvim-nix -- myfile.lua
```

### Option 2: Install to profile

```bash
# Install permanently — adds `nvim-nix` to your PATH
nix profile install github:Kailian-Jacy/nvim-config#nvim-nix

# Now available as:
nvim-nix
```

### Option 3: Temporary shell

```bash
# Enter a shell with nvim-nix available
nix shell github:Kailian-Jacy/nvim-config#nvim-nix

# Use it
nvim-nix myfile.lua

# Exit the shell to remove it
exit
```

### Option 4: NixOS / home-manager

```nix
# In your flake inputs:
inputs.nvim-config.url = "github:Kailian-Jacy/nvim-config";

# In your packages:
environment.systemPackages = [
  inputs.nvim-config.packages.${system}.nvim-nix
];
```

## Switching Between Versions

### Using switch-nvim.sh (Recommended)

```bash
# Check which version is the default
./nix/switch-nvim.sh status

# Make nixCats the default `nvim` command
./nix/switch-nvim.sh nix
source ~/.bashrc  # or ~/.zshrc

# Restore original nvim as default
./nix/switch-nvim.sh original
source ~/.bashrc  # or ~/.zshrc
```

The script manages a shell alias (`alias nvim="nvim-nix"`) in your `.bashrc` and/or `.zshrc`, using marker comments for clean insertion and removal.

### Manual Alias

```bash
# Add to your .bashrc or .zshrc:
alias nvim="nvim-nix"

# To bypass the alias temporarily:
command nvim       # uses original nvim
\nvim              # also uses original nvim
```

### Environment Variable

```bash
# Run any nvim binary with nixCats isolation:
NVIM_APPNAME=nvim-nix nvim

# Or export for the session:
export NVIM_APPNAME=nvim-nix
nvim  # now uses nvim-nix directories
```

### Direct Access (Always Available)

Regardless of aliases or defaults:

```bash
nvim-nix           # Always launches nixCats version
command nvim       # Always launches original (bypasses alias)
```

## Verifying Isolation

Run the verification script to confirm both versions are fully isolated:

```bash
./nix/verify-isolation.sh
```

This checks:
- Config directory isolation (`~/.config/nvim/` vs `~/.config/nvim-nix/`)
- Data directory isolation
- State directory isolation
- Cache directory isolation
- ShaDa file isolation
- Plugin directory isolation
- `stdpath('data')` runtime output

Expected output for a clean setup:

```
  ✅ PASS: Config directories are separate
  ✅ PASS: Data directories are separate
  ✅ PASS: State directories are separate
  ✅ PASS: Cache directories are separate
  ✅ PASS: stdpath('data') returns different paths for each version
```

## Uninstalling / Cleanup

### Remove nixCats version

```bash
# If installed via nix profile:
nix profile remove nvim-nix

# Remove nixCats data directories:
rm -rf ~/.config/nvim-nix
rm -rf ~/.local/share/nvim-nix
rm -rf ~/.local/state/nvim-nix
rm -rf ~/.cache/nvim-nix        # Linux
rm -rf ~/Library/Caches/nvim-nix  # macOS

# Remove alias if set:
./nix/switch-nvim.sh original
```

### Remove original version

If you've fully migrated to nixCats and want to clean up:

```bash
# Remove original nvim data (backup first!):
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak

# Make nixCats the default:
./nix/switch-nvim.sh nix
```

### Nix garbage collection

```bash
# Clean unused Nix store paths:
nix store gc
```

## Cross-Platform Notes

### macOS

- **Cache directory**: macOS defaults to `~/Library/Caches/` instead of `~/.cache/`. Set `XDG_CACHE_HOME=~/.cache` if you want Linux-style paths.
- **Homebrew Neovim**: If you have `brew install neovim`, the original `nvim` comes from Homebrew. nixCats installs separately via Nix and won't conflict.
- **PATH order**: Ensure `~/.nix-profile/bin` comes before `/opt/homebrew/bin` in your `$PATH` if you want `nvim-nix` to be found first.

### Linux

- **System Neovim**: If installed via `apt`/`dnf`/`pacman`, original `nvim` is in `/usr/bin/nvim`. nixCats installs to the Nix profile and won't conflict.
- **XDG compliance**: All paths follow XDG Base Directory specification. Override with `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME` as needed.

### NixOS

- On NixOS, you might not have a "system" neovim. Install the original via `programs.neovim.enable = true` in your NixOS config, and nixCats via the flake input.

## FAQ

### Q: Will nixCats break my existing neovim setup?

**No.** The nixCats build uses `NVIM_APPNAME = "nvim-nix"`, which creates completely separate directories. Your existing `~/.config/nvim/` is never touched.

### Q: Can I share plugins between the two versions?

**Not recommended.** The whole point of isolation is independence. nixCats manages plugins through the Nix store, which is fundamentally different from lazy.nvim's approach. Sharing would cause conflicts.

### Q: What about LSP servers?

Each version manages LSPs independently:
- **Original**: Mason.nvim downloads and manages LSP binaries
- **nixCats**: LSP servers are provided as Nix packages (declared in the flake)

### Q: Can I run both versions simultaneously?

**Yes!** Since they use different directories, you can have both open at the same time without any conflicts. They won't share undo history, registers, marks, or any state.

### Q: How do I update the nixCats version?

```bash
# If installed via nix profile:
nix profile upgrade nvim-nix

# Or re-install:
nix profile install github:Kailian-Jacy/nvim-config#nvim-nix
```

### Q: What if I set `NVIM_APPNAME` wrong?

If you set `NVIM_APPNAME` to a non-existent name (e.g., `NVIM_APPNAME=typo nvim`), Neovim will start with an empty config and create new directories. No existing data is harmed.

### Q: How do I migrate my config from original to nixCats?

See the main project README. In short:
1. Install nixCats: `nix profile install github:Kailian-Jacy/nvim-config#nvim-nix`
2. Run it: `nvim-nix`
3. Verify isolation: `./nix/verify-isolation.sh`
4. When satisfied, optionally make it default: `./nix/switch-nvim.sh nix`
