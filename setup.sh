#!/bin/zsh

set -e

###############################################
#   OS Detection (must be first)
###############################################

OS="Linux"
if [[ "$(uname)" == "Darwin" ]]; then
  OS="MacOS"
elif [[ "$(uname -s)" == Linux* ]]; then
  OS="Linux"
else
  echo "Unsupported OS. Exit."
  exit 1
fi
echo "Detected OS: $OS"

###############################################
#   Helper Functions
###############################################

# Check if a command is already installed; returns 0 if present.
check_installed() {
  command -v "$1" &> /dev/null
}

# Source a file only if it exists.
safe_source() {
  if [ -f "$1" ]; then
    source "$1"
  fi
}

###############################################
#   Options
###############################################

# Basic.
DEFAULT_SHELL=/usr/bin/zsh
NVIM_CONF_LINK=~/.config/nvim
TMUX_CONF_LINK=~/.tmux.conf
NEOVIDE_CONF_LINK=~/.config/neovide/config.toml
NVIM_INSTALL_PATH=$HOME/.local/nvim/
DEFAULT_ENV_FILE_PATH=~/.zprofile
INSTALL_DEPENDENCIES="git curl " # Everything relies on them...
INSTALL_DEPENDENCIES+="cmake make gcc " # required by luasnip, ray-x and treesitter.
INSTALL_DEPENDENCIES+="tmux lazygit zoxide " # handy cmd tools.
INSTALL_DEPENDENCIES+="fzf ripgrep fd " # builtin searches.
INSTALL_DEPENDENCIES+="node " # required by copilot (npm comes with node).
INSTALL_DEPENDENCIES+="unzip zip lua@5.4 luarocks "
INSTALL_DEPENDENCIES+="sqlite " # required by bookmarks.nvim
INSTALL_DEPENDENCIES+="gh " # required by Snacks.nvim/gh
INSTALL_FONT_PATH=""
CONTINUE_ON_ERROR=true
INSTALL_NVIM_FROM_SOURCE=0
DEFAULT_MASON_PATH="$HOME/.local/share/nvim/mason/bin"
SNIPPET_LINK="" # Set to a path if you want snippets linked, e.g. ~/.config/nvim/snip

if [[ "$OS" == "MacOS" ]]; then
  INSTALL_FONT_PATH="/Library/Fonts/"
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES pngpaste"
else
  INSTALL_FONT_PATH="$HOME/.local/share/fonts/"
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES xsel"
fi

# Script directory detection.
CURRENT_ABS=$(realpath "$0")
CURRENT_BASEDIR=$(dirname "$CURRENT_ABS")
DEFAULT_SHELL_RC_FILENAME=".$(basename "$DEFAULT_SHELL")rc"
DEFAULT_SHELL_RC="$HOME/$DEFAULT_SHELL_RC_FILENAME" # Ensure absolute path
echo "Writing to shell rc: ${DEFAULT_SHELL_RC}"

# Safely append source line to shell rc (create if needed).
touch "$DEFAULT_SHELL_RC"
if ! grep -qF "source $DEFAULT_ENV_FILE_PATH" "$DEFAULT_SHELL_RC" 2>/dev/null; then
  echo "source $DEFAULT_ENV_FILE_PATH" >> "$DEFAULT_SHELL_RC"
fi

if [ "$INSTALL_NVIM_FROM_SOURCE" -ne 0 ]; then
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES gcc cmake"
else
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES neovim"
fi

###############################################
#   Install Homebrew
###############################################

echo "Installing homebrew..."
if check_installed brew; then
  echo "Homebrew already installed. Using $(which brew)"
else
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$OS" == "MacOS" ]]; then
    # On macOS, brew installer should have set up paths already.
    if ! check_installed brew; then
      echo "Error: Homebrew installation failed on macOS. exit."
      exit 1
    fi
  elif [[ "$OS" == "Linux" ]]; then
    touch "$DEFAULT_ENV_FILE_PATH"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$DEFAULT_ENV_FILE_PATH"
  fi
  safe_source "$DEFAULT_ENV_FILE_PATH"
  if ! check_installed brew; then
      echo "Error: Homebrew installation failed. exit."
      exit 1
  fi
  echo "Homebrew successfully installed."
fi

HOMEBREW_BIN_PATH=$(which brew)
cat >> "$DEFAULT_SHELL_RC" << EOF
# alias brew.
function brew() {
  HOMEBREW_NO_AUTO_UPDATE=1 PATH="$(dirname "$HOMEBREW_BIN_PATH"):\$PATH" $HOMEBREW_BIN_PATH "\$@"
}
EOF
touch "$DEFAULT_ENV_FILE_PATH"
echo "PATH=\$PATH:$(brew --prefix)/bin" >> "$DEFAULT_ENV_FILE_PATH"
safe_source "$DEFAULT_ENV_FILE_PATH"
safe_source "$DEFAULT_SHELL_RC"

###############################################
#   Install Dependencies
###############################################

echo "Installing dependencies..."

# Filter out already-installed dependencies.
DEPS_TO_INSTALL=""
for dep in $(echo $INSTALL_DEPENDENCIES); do
  # Map brew formula names to command names where they differ.
  cmd_name="$dep"
  case "$dep" in
    lua@5.4) cmd_name="lua" ;;
    fd) cmd_name="fd" ;; # fd-find on some systems, but brew installs as fd
  esac

  if check_installed "$cmd_name"; then
    echo "  ✓ $dep already installed, skipping."
  else
    DEPS_TO_INSTALL="$DEPS_TO_INSTALL $dep"
  fi
done

if [ -n "$DEPS_TO_INSTALL" ]; then
  echo "Installing:$DEPS_TO_INSTALL"
  if ! echo "$DEPS_TO_INSTALL" | xargs brew install; then
    if [ "$CONTINUE_ON_ERROR" = true ]; then
      echo "Warning: Some dependencies failed to install. Continuing..."
    else
      echo "Error: Dependency installation failed."
      exit 1
    fi
  fi
else
  echo "All dependencies already installed."
fi

echo "eval \"\$(zoxide init $(basename $DEFAULT_SHELL))\"" >> "${DEFAULT_SHELL_RC}"

if check_installed npm; then
  npm i -g vscode-langservers-extracted
else
  echo "Warning: npm not found, skipping vscode-langservers-extracted installation."
fi
# pip3 install neovim-remote # TODO: pip3 python config later.

if [ "$INSTALL_NVIM_FROM_SOURCE" -ne 0 ]; then
  # Clone and compile neovim.
  echo "Install neovim to: $NVIM_INSTALL_PATH"
  mkdir -p "$NVIM_INSTALL_PATH"
  cd "$CURRENT_BASEDIR/neovim-source" && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$NVIM_INSTALL_PATH" && make install
  cd "$CURRENT_BASEDIR" # Return to the script's base directory

  echo "export PATH=\"$NVIM_INSTALL_PATH/bin:\$PATH\"" >> "${DEFAULT_ENV_FILE_PATH}" # Ensure PATH is exported and $PATH is escaped
fi

###############################################
#   Symlinks
###############################################

function backup_and_link() {
  local source="$1"
  local target="$2"
  if [ -z "$target" ]; then # More standard check for empty string
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

# Ensure using absolute paths from CURRENT_BASEDIR for sources
backup_and_link "$CURRENT_BASEDIR/config.nvim/" "${NVIM_CONF_LINK}"
backup_and_link "$CURRENT_BASEDIR/config.others/tmux.conf" "${TMUX_CONF_LINK}"
backup_and_link "$CURRENT_BASEDIR/config.others/neovide.config.toml" "${NEOVIDE_CONF_LINK}"

# Only link snippets if SNIPPET_LINK is defined.
if [ -n "$SNIPPET_LINK" ]; then
  backup_and_link "$CURRENT_BASEDIR/config.nvim/snip" "${SNIPPET_LINK}"
fi

###############################################
#   Fonts
###############################################

if [ -n "$INSTALL_FONT_PATH" ]; then
  echo "Installing fonts to $INSTALL_FONT_PATH..."
  mkdir -p "$INSTALL_FONT_PATH" # Ensure the directory exists

  # Use find to robustly copy font files
  if [ -d "$CURRENT_BASEDIR/monolisa-nerd-font" ]; then
    find "$CURRENT_BASEDIR/monolisa-nerd-font" -type f \( -name '*Nerd*' -o -name '*NerdFont*' \) -print0 | while IFS= read -r -d $'\0' font_file; do
      echo "Copying font: $(basename "$font_file") to $INSTALL_FONT_PATH"
      cp "$font_file" "$INSTALL_FONT_PATH/"
    done
  else
    echo "Warning: monolisa-nerd-font directory not found. Skipping font copy."
  fi

  # Update font cache on Linux
  if [[ "$OS" == "Linux" ]] && check_installed fc-cache; then
    echo "Updating font cache..."
    fc-cache -fv
  fi
  echo "Font installation complete."
else
  echo "INSTALL_FONT_PATH not set. Skipping font installation."
fi

###############################################
#   Environment Variables
###############################################

touch "$DEFAULT_ENV_FILE_PATH"
echo "export OPENROUTER_API_KEY=" >> "${DEFAULT_ENV_FILE_PATH}"
echo "export DEEPSEEK_API_KEY=" >> "${DEFAULT_ENV_FILE_PATH}"
echo "export PATH=\$PATH:$DEFAULT_MASON_PATH:$HOME/.local/bin" >> "${DEFAULT_ENV_FILE_PATH}"

###############################################
#   Plugin Installation (with timeout)
###############################################

safe_source "${DEFAULT_ENV_FILE_PATH}"
echo "Starting neovim to install plugins, parsers and lsps. This may take some time."

NVIM_TIMEOUT=300 # 5 minutes per command

timeout "$NVIM_TIMEOUT" nvim --headless +":Lazy restore" +q 2>&1 || {
  if [ "$CONTINUE_ON_ERROR" = true ]; then
    echo "Warning: Lazy restore timed out or failed. Continuing..."
  else
    echo "Error: Lazy restore failed."; exit 1
  fi
}

timeout "$NVIM_TIMEOUT" nvim --headless +"lua print('Dependencies successfully installed.')" +q 2>&1 || {
  if [ "$CONTINUE_ON_ERROR" = true ]; then
    echo "Warning: nvim dependency check timed out or failed. Continuing..."
  else
    echo "Error: nvim dependency check failed."; exit 1
  fi
}

timeout "$NVIM_TIMEOUT" nvim --headless +"MasonToolsInstall" +q 2>&1 || {
  if [ "$CONTINUE_ON_ERROR" = true ]; then
    echo "Warning: MasonToolsInstall timed out or failed. Continuing..."
  else
    echo "Error: MasonToolsInstall failed."; exit 1
  fi
}

###############################################
#   Done
###############################################

cat <<EOF

Neovim is successfully installed. Please:
  1. Setup API keys in $DEFAULT_ENV_FILE_PATH (e.g., OPENROUTER_API_KEY, DEEPSEEK_API_KEY).
  2. source $DEFAULT_SHELL_RC.
EOF
