#!/bin/bash -e

SHELL_DOT=~/.bashrc
INSTALLER="sudo apt"
ENSURE="-y"
NVIM="/usr/bin/nvim"

function check_before_install() {
    if command -v $1 &> /dev/null; then
        echo "$1 is already installed. Skipping installation."
        return
    fi
    ($2)
    echo "$1 installed"
}

function install_neovim() {
     function install_neovim() {
        if [[ "$(uname)" == "Darwin" ]]; then
            $INSTALLER install $ENSURE neovim
        elif [[ "$(uname)" == "Linux" ]]; then
            $INSTALLER install $ENSURE curl
            curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
            sudo rm -rf /opt/nvim-linux64
            sudo tar -C /opt -xzf nvim-linux64.tar.gz
            rm nvim-linux64.tar.gz
        fi
        sudo ln -s /opt/nvim-linux64/bin/nvim $NVIM
        echo -e "alias vim=nvim \nalias v=nvim" >> $SHELL_DOT
        echo "export PATH=$PATH:/opt/nvim-linux64/bin" >> $SHELL_DOT
    }
    check_before_install nvim install_neovim
    source $SHELL_DOT
}

CURRENT_ABS=$(realpath "$0")
echo $CURRENT_ABS
CONFIG_SOURCE=$(dirname "$CURRENT_ABS")/
echo $CONFIG_SOURCE

function clone_config() {
	mkdir -p ~/.config
    rm -dfr ~/.config/nvim 
	# git clone https://github.com/LazyVim/starter ~/.config/nvim
	ln -s $CONFIG_SOURCE/config.nvim ~/.config/nvim
}

function dependencies() {

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        $INSTALLER install $ENSURE node
        $INSTALLER install $ENSURE lazygit
        $INSTALLER install $ENSURE zoxide
    elif [[ "$(uname)" == "Linux" ]]; then
        # Linux
        $INSTALLER install $ENSURE nodejs
        function install_lazygit() {
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf lazygit.tar.gz lazygit
            sudo install lazygit -D -t /usr/local/bin/
            rm lazygit.tar.gz lazygit
        }
        function install_zoxide() {
            git clone https://github.com/ajeetdsouza/zoxide
            cd zoxide && ./install.sh
            echo "export PATH=$PATH:$HOME/.local/bin" >> $SHELL_DOT
            source $SHELL_DOT
            rm -dfr zoxide
            eval "$(zoxide init bash)"
        }
        check_before_install lazygit install_lazygit
    fi

    $INSTALLER install $ENSURE xsel golang make g++ unzip zip npm ripgrep cmake

    function install_fzf() {
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install
    }
    # Bug: Some times fzf says lib not found. manual installation works.
    # cd ~/.local/share/nvim/lazy/telescope-fzf-native.nvim && make && cd -
    check_before_install fzf install_fzf
    rm -dfr ~/.config/nvim/pack/github/start/copilot.vim
    git clone https://github.com/github/copilot.vim.git \
        ~/.config/nvim/pack/github/start/copilot.vim
    # wget -P ~/.vim/pack/github/start/copilot.vim/dist/ https://copilot.aistore.sale/proxy.js
    # echo "require('./proxy.js');" >>~/.vim/pack/github/start/copilot.vim/dist/language-server.js

    source $SHELL_DOT
    # $INSTALLER install --cask font-jetbrains-mono-nerd-font
    $NVIM
}

function todo() {
    echo "you can choose to clean up:"
    echo "1. login to github copilot to use avante;"
    echo "2. uncomment corresponding mason ensure_install after setting up language envs."
}

install_neovim
clone_config
dependencies
todo
