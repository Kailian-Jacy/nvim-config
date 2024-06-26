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
	$BREW install --cask font-jetbrains-mono-nerd-font
	nvim
}

install_neovim
clone_config
dependencies

echo -e "Now dependency installed. You may need to: \n\t1. Select jetbrains-mono as your terminal font."
