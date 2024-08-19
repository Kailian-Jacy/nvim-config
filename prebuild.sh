#!/bin/zsh -e

function install_neovim() {
	brew install neovim
 	echo "alias vim=nvim" >> ~/.zshrc
  	source ~/.zshrc
}

CURRENT_ABS=${0:a}
CONFIG_SOURCE=$(dirname $CURRENT_ABS)/

function clone_config() {
	mkdir -p ~/.config
	git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim 
	ln -s $CONFIG_SOURCE/config.nvim ~/.config/nvim
}

function dependencies() {
 	brew install node
 	brew install lazygit xsel
	brew install --cask font-jetbrains-mono-nerd-font
	nvim
}

install_neovim
clone_config
dependencies

echo -e "Now dependency installed. You may need to: \n\t1. Select jetbrains-mono as your terminal font.\n\t2. :Mason into lsp configs to install lsp.\n"
