#!/bin/zsh

set -e

# detect OS.
OS="Linux"
if [[ "$(uname)" == "Darwin" ]]; then
  OS="MacOS"
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
  OS="Linux"
else
  echo "Not supported OS. Exit."
fi

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
INSTALL_DEPENDENCIES="git curl tar" # Everything relies on them...
INSTALL_DEPENDENCIES+="tmux lazygit zoxide" # handy cmd tools.
INSTALL_DEPENDENCIES+="fzf ripgrep fd" # buildin searchs.
INSTALL_DEPENDENCIES+="node" # required by copilot.
INSTALL_DEPENDENCIES+="unzip zip npm lua@5.4 luarocks"
INSTALL_DEPENDENCIES+="sqlite" # required by bookmarks.nvim
INSTALL_DEPENDENCIES+="cmake make" # requried by luasnip, ray-x and treesitter.
INSTALL_FONT_PATH=""
CONTINUE_ON_ERROR=1
INSTALL_NVIM_FROM_SOURCE=0
DEFAULT_MASON_PATH="$HOME/.local/share/nvim/mason/bin"
if [[ $OS == "MacOS" ]]; then
  INSTALL_FONT_PATH="/Library/Fonts/"
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES pngpaste"
else
  INSTALL_FONT_PATH="$HOME/.local/share/fonts/"
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES xsel"
fi

# generated options.
CURRENT_ABS=$(realpath $0)
CURRENT_BASEDIR=$(dirname $CURRENT_ABS)
DEFAULT_SHELL_RC_FILENAME=".$(basename "$DEFAULT_SHELL")rc"
DEFAULT_SHELL_RC="$HOME/$DEFAULT_SHELL_RC_FILENAME" # Ensure absolute path
echo "Writing to shell rc: ${DEFAULT_SHELL_RC}"
echo "source $DEFAULT_ENV_FILE_PATH" >> "$DEFAULT_SHELL_RC"

if [ $INSTALL_NVIM_FROM_SOURCE -ne 0 ]; then
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES gcc cmake"
else
  INSTALL_DEPENDENCIES="$INSTALL_DEPENDENCIES neovim"
fi

# install homebrew for dependencies.
echo "Installing homebrew..."
if command -v "brew" &> /dev/null; then
  echo "Homebrew already installed. Using $(which brew)"
else
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ $OS == "Darwin" ]]; then
    echo "Install homebrew first. Exit."
    exit 1
  elif [[ $OS == "Linux" ]]; then
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> $DEFAULT_ENV_FILE_PATH
  fi
  source $DEFAULT_ENV_FILE_PATH
  if ! command -v brew &> /dev/null; then
      echo "Error: Homebrew installation failed. exit."
      exit 1
  fi
  echo "Homebrew successfully installed."
fi

HOMEBREW_BIN_PATH=$(which brew)
cat >> $DEFAULT_SHELL_RC << EOF
# alias brew.
function brew() {
  HOMEBREW_NO_AUTO_UPDATE=1 PATH="$(dirname $HOMEBREW_BIN_PATH):\$PATH" $HOMEBREW_BIN_PATH "\$@"
}
EOF
echo "PATH=\$PATH:$(brew --prefix)/bin" >> $DEFAULT_ENV_FILE_PATH
source $DEFAULT_ENV_FILE_PATH
source $DEFAULT_SHELL_RC

# Install dependencies.
echo "Installing dependencies..."
echo $INSTALL_DEPENDENCIES | xargs brew install || $CONTINUE_ON_ERROR

echo "eval \"\$(zoxide init $(basename $DEFAULT_SHELL))\"" >> ${DEFAULT_SHELL_RC}
npm i -g vscode-langservers-extracted
# pip3 install neovim-remote # TODO: pip3 python config later.

if [ "$INSTALL_NVIM_FROM_SOURCE" -ne 0 ]; then
  # Clone and compile neovim.
  echo "Install neovim to: $NVIM_INSTALL_PATH"
  mkdir -p "$NVIM_INSTALL_PATH"
  cd "$CURRENT_BASEDIR/neovim-source" && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$NVIM_INSTALL_PATH" && make install
  cd "$CURRENT_BASEDIR" # Return to the script's base directory

  echo "export PATH=\"$NVIM_INSTALL_PATH/bin:\$PATH\"" >> "${DEFAULT_ENV_FILE_PATH}" # Ensure PATH is exported and $PATH is escaped
fi

# Make all links.
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
backup_and_link "$CURRENT_BASEDIR/config.others/tmux.conf" "${TMUX_CONF_LINK}" # Corrected target
backup_and_link "$CURRENT_BASEDIR/config.others/neovide.config.toml" "${NEOVIDE_CONF_LINK}"
backup_and_link "$CURRENT_BASEDIR/config.nvim/snip" "${SNIPPET_LINK}" || [ $CONTINUE_ON_ERROR = true ]

# if INSTALL_FONT_PATH is set, install Nerd fonts
if [ -n "$INSTALL_FONT_PATH" ]; then
  echo "Installing fonts to $INSTALL_FONT_PATH..."
  mkdir -p "$INSTALL_FONT_PATH" # Ensure the directory exists

  # Use find to robustly copy font files
  # Copy only files ending with *Nerd* or *NerdFont* patterns, common for Nerd Fonts
  # Adjust pattern if your font names differ significantly
  find "$CURRENT_BASEDIR/monolisa-nerd-font" -type f \( -name '*Nerd*' -o -name '*NerdFont*' \) -print0 | while IFS= read -r -d $'\0' font_file; do
    echo "Copying font: $(basename "$font_file") to $INSTALL_FONT_PATH"
    cp "$font_file" "$INSTALL_FONT_PATH/"
  done

  # Update font cache on Linux
  if [[ "$OS" == "Linux" ]] && command -v fc-cache &> /dev/null; then
    echo "Updating font cache..."
    fc-cache -fv
  fi
  echo "Font installation complete."
else
  echo "INSTALL_FONT_PATH not set. Skipping font installation."
fi

# Require user to set tokens in .zprofile file.
echo "export OPENROUTER_API_KEY=" >> ${DEFAULT_ENV_FILE_PATH}
echo "export DEEPSEEK_API_KEY=" >> ${DEFAULT_ENV_FILE_PATH}
echo "export PATH=\$PATH:$DEFAULT_MASON_PATH:$HOME/.local/bin" >> ${DEFAULT_ENV_FILE_PATH}

# Start nvim and install all the dependencies
source ${DEFAULT_ENV_FILE_PATH}
nvim --headless +"lua print('Dependencies successfully installed.')" +q || [ $CONTINUE_ON_ERROR ]
nvim --headless +"MasonToolsInstall" +q || [ $CONTINUE_ON_ERROR ]

# Remind todo list to the user:
cat <<EOF
Neovim is successfully installed. Please:
  1. Setup API keys in $DEFAULT_ENV_FILE_PATH (e.g., OPENROUTER_API_KEY, DEEPSEEK_API_KEY).
  2. source $DEFAULT_SHELL_RC.
EOF
