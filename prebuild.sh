#!/bin/zsh -e

BREW="HOMEBREW_NO_AUTO_UPDATE=1 brew"

function install_neovim() {
	$BREW install neovim
 	echo "alias vim=nvim" >> ~/.zshrc
  	source ~/.zshrc
}

CURRENT_ABS=${0:a}
CONFIG_SOURCE=$(dirname $CURRENT_ABS)/

function clone_config() {
	mkdir -p ~/.config
	ln -s CONFIG_SOURCE/config.nvim ~/.config/nvim

}

function dependencies() {
 	$BREW install node
	nvim
}

install_neovim
clone_config
dependencies
