#!/bin/zsh

set -e

###############################################
#   Options
###############################################

# OS detection — must happen before anything uses $OS.
OS="Linux"
if [[ "$(uname)" == "Darwin" ]]; then
  OS="MacOS"
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
  OS="Linux"
else
  echo "Unsupported OS. Exit."
  exit 1
fi

# Detect if running in a Docker container.
IN_DOCKER=false
if [[ -f /.dockerenv ]] || grep -qsF 'docker\|containerd' /proc/1/cgroup 2>/dev/null; then
  IN_DOCKER=true
fi

# Detect if running as root.
IS_ROOT=false
if [[ $(id -u) -eq 0 ]]; then
  IS_ROOT=true
fi

# Install mode selection:
#   --minimal   : neovim + config link + treesitter build deps only
#   --docker    : minimal + headless plugin install, skip fonts/clipboard tools
#   --full      : everything (default)
INSTALL_MODE="${1:-full}"
case "$INSTALL_MODE" in
  --minimal) INSTALL_MODE="minimal" ;;
  --docker)  INSTALL_MODE="docker" ;;
  --full)    INSTALL_MODE="full" ;;
  *)         INSTALL_MODE="full" ;;
esac

# Auto-detect docker mode
if [[ "$IN_DOCKER" == "true" && "$INSTALL_MODE" == "full" ]]; then
  echo "Detected Docker environment. Switching to --docker install mode."
  INSTALL_MODE="docker"
fi

# Basic paths.
DEFAULT_SHELL=/usr/bin/zsh
NVIM_CONF_LINK=~/.config/nvim
TMUX_CONF_LINK=~/.tmux.conf
NEOVIDE_CONF_LINK=~/.config/neovide/config.toml
NVIM_INSTALL_PATH="$HOME/.local/nvim/"
DEFAULT_ENV_FILE_PATH=~/.zprofile
CONTINUE_ON_ERROR=true
INSTALL_NVIM_FROM_SOURCE=0
DEFAULT_MASON_PATH="$HOME/.local/share/nvim/mason/bin"
SNIPPET_LINK="$HOME/.config/nvim/snip"

# Generated options.
CURRENT_ABS=$(realpath "$0")
CURRENT_BASEDIR=$(dirname "$CURRENT_ABS")
DEFAULT_SHELL_RC_FILENAME=".$(basename "$DEFAULT_SHELL")rc"
DEFAULT_SHELL_RC="$HOME/$DEFAULT_SHELL_RC_FILENAME"

###############################################
#   Helper functions
###############################################

check_installed() {
  command -v "$1" &>/dev/null
}

safe_source() {
  [[ -f "$1" ]] && source "$1"
}

# Idempotent append: only adds line if not already present.
append_if_missing() {
  local file="$1"
  local line="$2"
  if ! grep -qF "$line" "$file" 2>/dev/null; then
    echo "$line" >> "$file"
  fi
}

###############################################
#   Package Manager Detection
###############################################
# Strategy:
#   - macOS: always use brew (standard, bottles work)
#   - Linux (not root, not docker): prefer brew (cross-platform consistency)
#   - Linux (root or docker): use apt + binary downloads (brew refuses root)

USE_BREW=true
if [[ "$OS" == "Linux" && ("$IS_ROOT" == "true" || "$IN_DOCKER" == "true") ]]; then
  USE_BREW=false
fi

echo "=== Install Configuration ==="
echo "  OS: $OS"
echo "  Docker: $IN_DOCKER"
echo "  Root: $IS_ROOT"
echo "  Mode: $INSTALL_MODE"
echo "  Package Manager: $(if $USE_BREW; then echo 'brew'; else echo 'apt + binaries'; fi)"
echo "============================="

###############################################
#   Shell RC setup
###############################################
echo "Writing to shell rc: ${DEFAULT_SHELL_RC}"
touch "$DEFAULT_ENV_FILE_PATH"
touch "$DEFAULT_SHELL_RC"
append_if_missing "$DEFAULT_SHELL_RC" "source $DEFAULT_ENV_FILE_PATH"

###############################################
#   Install Dependencies (Brew Path)
###############################################
install_via_brew() {
  local INSTALL_DEPENDENCIES="git curl "
  INSTALL_DEPENDENCIES+="cmake make gcc " # required by luasnip, ray-x and treesitter.
  INSTALL_DEPENDENCIES+="tmux lazygit zoxide "
  INSTALL_DEPENDENCIES+="fzf ripgrep fd "
  INSTALL_DEPENDENCIES+="node " # npm comes with node
  INSTALL_DEPENDENCIES+="unzip zip lua@5.4 luarocks "
  INSTALL_DEPENDENCIES+="sqlite "
  INSTALL_DEPENDENCIES+="gh "

  if [[ "$INSTALL_MODE" != "docker" && "$INSTALL_MODE" != "minimal" ]]; then
    if [[ "$OS" == "MacOS" ]]; then
      INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES pngpaste"
    else
      INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES xsel"
    fi
  fi

  if [ "$INSTALL_NVIM_FROM_SOURCE" -eq 0 ]; then
    INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES neovim"
  fi

  echo "Installing homebrew..."
  if check_installed "brew"; then
    echo "Homebrew already installed. Using $(which brew)"
  else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ "$OS" == "Linux" ]]; then
      append_if_missing "$DEFAULT_ENV_FILE_PATH" 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    fi
    safe_source "$DEFAULT_ENV_FILE_PATH"
    if ! check_installed "brew"; then
      echo "Error: Homebrew installation failed. exit."
      exit 1
    fi
    echo "Homebrew successfully installed."
  fi

  # Verify brew uses canonical path for bottles (Linux).
  if [[ "$OS" == "Linux" ]]; then
    local brew_prefix
    brew_prefix=$(brew --prefix)
    if [[ "$brew_prefix" != "/home/linuxbrew/.linuxbrew" ]]; then
      echo "⚠️  Brew is installed to a non-standard path ($brew_prefix)."
      echo "   Packages may compile from source instead of using bottles."
      echo "   Recommended: install to /home/linuxbrew/.linuxbrew"
    fi
  fi

  HOMEBREW_BIN_PATH=$(which brew)
  if ! grep -qF "function brew()" "$DEFAULT_SHELL_RC" 2>/dev/null; then
    cat >> "$DEFAULT_SHELL_RC" << EOF
# alias brew.
function brew() {
  HOMEBREW_NO_AUTO_UPDATE=1 PATH="$(dirname "$HOMEBREW_BIN_PATH"):\$PATH" $HOMEBREW_BIN_PATH "\$@"
}
EOF
  fi

  append_if_missing "$DEFAULT_ENV_FILE_PATH" "PATH=\$PATH:$(brew --prefix)/bin"
  safe_source "$DEFAULT_ENV_FILE_PATH"
  safe_source "$DEFAULT_SHELL_RC"

  echo "Installing dependencies via brew..."
  echo "$INSTALL_DEPENDENCIES" | xargs brew install || {
    if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
      echo "Error: Failed to install some dependencies."
      exit 1
    fi
    echo "Warning: Some dependencies failed to install. Continuing..."
  }
}

###############################################
#   Install Dependencies (APT + Binary Path)
###############################################
install_via_apt() {
  echo "Installing dependencies via apt + binary downloads..."

  # System packages via apt.
  local APT_PACKAGES="git curl ca-certificates sudo"
  APT_PACKAGES+=" cmake make gcc g++ build-essential"
  APT_PACKAGES+=" unzip zip"
  APT_PACKAGES+=" ripgrep fd-find"
  APT_PACKAGES+=" nodejs npm"
  APT_PACKAGES+=" lua5.4 luarocks libsqlite3-dev sqlite3"
  APT_PACKAGES+=" fontconfig"

  if [[ "$INSTALL_MODE" != "docker" && "$INSTALL_MODE" != "minimal" ]]; then
    APT_PACKAGES+=" xsel tmux"
  else
    APT_PACKAGES+=" tmux"
  fi

  apt-get update
  apt-get install -y --no-install-recommends $APT_PACKAGES
  rm -rf /var/lib/apt/lists/*

  # Create fd symlink (apt installs as fdfind).
  if check_installed "fdfind" && ! check_installed "fd"; then
    ln -sf "$(which fdfind)" /usr/local/bin/fd
  fi

  # Neovim: install from official release tarball.
  if ! check_installed "nvim"; then
    echo "Installing neovim from official release..."
    curl -fsSL https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz \
      | tar -C /opt -xzf -
    ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
  fi

  # Lazygit: install from GitHub release.
  if ! check_installed "lazygit"; then
    echo "Installing lazygit from GitHub release..."
    local LAZYGIT_VERSION
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
      | grep -Po '"tag_name": *"v\K[^"]*')
    curl -fsSLo /tmp/lazygit.tar.gz \
      "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    install /tmp/lazygit /usr/local/bin/
    rm -f /tmp/lazygit.tar.gz /tmp/lazygit
  fi

  # Zoxide: install via official script.
  if ! check_installed "zoxide"; then
    echo "Installing zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    append_if_missing "$DEFAULT_ENV_FILE_PATH" "export PATH=\$PATH:\$HOME/.local/bin"
  fi

  # FZF: install from GitHub release.
  if ! check_installed "fzf"; then
    echo "Installing fzf..."
    local FZF_VERSION
    FZF_VERSION=$(curl -s "https://api.github.com/repos/junegunn/fzf/releases/latest" \
      | grep -Po '"tag_name": *"v?\K[^"]*')
    curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
      | tar -C /usr/local/bin -xzf -
  fi

  # GitHub CLI: install via official apt repo.
  if ! check_installed "gh"; then
    echo "Installing GitHub CLI..."
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt-get update
    apt-get install -y gh
    rm -rf /var/lib/apt/lists/*
  fi
}

###############################################
#   Install via selected package manager
###############################################
if $USE_BREW; then
  install_via_brew
else
  install_via_apt
fi

###############################################
#   Common post-install steps
###############################################

# Zoxide init.
append_if_missing "$DEFAULT_SHELL_RC" "eval \"\$(zoxide init $(basename "$DEFAULT_SHELL"))\""

# NPM global packages.
if check_installed "npm"; then
  npm i -g vscode-langservers-extracted
else
  echo "Warning: npm not found. Skipping vscode-langservers-extracted installation."
fi

###############################################
#   Build neovim from source (optional)
###############################################
if [ "$INSTALL_NVIM_FROM_SOURCE" -ne 0 ]; then
  echo "Install neovim to: $NVIM_INSTALL_PATH"
  mkdir -p "$NVIM_INSTALL_PATH"
  cd "$CURRENT_BASEDIR/neovim-source" && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$NVIM_INSTALL_PATH" && make install
  cd "$CURRENT_BASEDIR"
  append_if_missing "$DEFAULT_ENV_FILE_PATH" "export PATH=\"$NVIM_INSTALL_PATH/bin:\$PATH\""
fi

###############################################
#   Symlinks
###############################################
backup_and_link() {
  local source="$1"
  local target="$2"
  if [ -z "$target" ]; then
    echo "Skipped linking $source (empty target path)"
    return
  fi

  echo "Linking $source to $target"
  if [ -L "$target" ] || [ -e "$target" ]; then
    echo "Backing up existing $target to $target.nvim.bak"
    if ! mv "$target" "$target.nvim.bak"; then
      echo "Error: Failed to back up $target. Please check permissions or manually remove/rename it."
      return 1
    fi
  else
    mkdir -p "$(dirname "$target")"
  fi

  if ln -s "$source" "$target"; then
    echo "Successfully linked $source to $target"
  else
    echo "Error: Failed to link $source to $target."
  fi
}

backup_and_link "$CURRENT_BASEDIR/config.nvim/" "${NVIM_CONF_LINK}"
backup_and_link "$CURRENT_BASEDIR/config.others/tmux.conf" "${TMUX_CONF_LINK}"

if [[ "$INSTALL_MODE" != "minimal" && "$INSTALL_MODE" != "docker" ]]; then
  backup_and_link "$CURRENT_BASEDIR/config.others/neovide.config.toml" "${NEOVIDE_CONF_LINK}"
fi

backup_and_link "$CURRENT_BASEDIR/config.nvim/snip" "${SNIPPET_LINK}" || [[ "$CONTINUE_ON_ERROR" == "true" ]]

###############################################
#   Font installation (skip in minimal/docker)
###############################################
if [[ "$INSTALL_MODE" == "full" ]]; then
  INSTALL_FONT_PATH=""
  if [[ "$OS" == "MacOS" ]]; then
    INSTALL_FONT_PATH="/Library/Fonts/"
  else
    INSTALL_FONT_PATH="$HOME/.local/share/fonts/"
  fi

  if [ -n "$INSTALL_FONT_PATH" ]; then
    echo "Installing fonts to $INSTALL_FONT_PATH..."
    mkdir -p "$INSTALL_FONT_PATH"

    if [ -d "$CURRENT_BASEDIR/monolisa-nerd-font" ]; then
      find "$CURRENT_BASEDIR/monolisa-nerd-font" -type f \( -name '*Nerd*' -o -name '*NerdFont*' \) -print0 | while IFS= read -r -d $'\0' font_file; do
        echo "Copying font: $(basename "$font_file") to $INSTALL_FONT_PATH"
        cp "$font_file" "$INSTALL_FONT_PATH/"
      done
    else
      echo "monolisa-nerd-font directory not found. Skipping font installation."
    fi

    if [[ "$OS" == "Linux" ]] && check_installed "fc-cache"; then
      echo "Updating font cache..."
      fc-cache -fv
    fi
    echo "Font installation complete."
  fi
fi

###############################################
#   Environment variables
###############################################
append_if_missing "$DEFAULT_ENV_FILE_PATH" "export OPENROUTER_API_KEY="
append_if_missing "$DEFAULT_ENV_FILE_PATH" "export DEEPSEEK_API_KEY="
append_if_missing "$DEFAULT_ENV_FILE_PATH" "export PATH=\$PATH:$DEFAULT_MASON_PATH:$HOME/.local/bin"

###############################################
#   Neovim plugin installation
###############################################
safe_source "${DEFAULT_ENV_FILE_PATH}"
echo "Starting neovim to install plugins, parsers and lsps. This may take some time."

timeout 300 nvim --headless +":Lazy restore" +q || {
  if [[ "$CONTINUE_ON_ERROR" == "true" ]]; then
    echo "Warning: Lazy restore timed out or failed. Continuing..."
  else
    echo "Error: Lazy restore failed."
    exit 1
  fi
}

timeout 300 nvim --headless +"lua print('Dependencies successfully installed.')" +q || {
  if [[ "$CONTINUE_ON_ERROR" == "true" ]]; then
    echo "Warning: Neovim dependency check timed out or failed. Continuing..."
  else
    echo "Error: Neovim dependency check failed."
    exit 1
  fi
}

if [[ "$INSTALL_MODE" != "minimal" ]]; then
  timeout 300 nvim --headless +"MasonToolsInstall" +q || {
    if [[ "$CONTINUE_ON_ERROR" == "true" ]]; then
      echo "Warning: MasonToolsInstall timed out or failed. Continuing..."
    else
      echo "Error: MasonToolsInstall failed."
      exit 1
    fi
  }
fi

###############################################
#   Done
###############################################
cat <<EOF

✅ Neovim is successfully installed (mode: $INSTALL_MODE).

Please:
  1. Setup API keys in $DEFAULT_ENV_FILE_PATH (e.g., OPENROUTER_API_KEY, DEEPSEEK_API_KEY).
  2. source $DEFAULT_SHELL_RC

Install modes:
  ./setup.sh --full     Full installation (default)
  ./setup.sh --minimal  Core neovim only (no fonts, no extra tools)
  ./setup.sh --docker   Optimized for Docker containers
EOF
