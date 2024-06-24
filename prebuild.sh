#!/bin/bash -e

function install_neovim() {
	HOMEBREW_NO_AUTO_UPDATE=1 brew install neovim
}

CONFIG_SOURCE=$(dirname "$0")/

function clone_config() {
	mkdir -p ~/.config
	ln -s CONFIG_SOURCE/config.nvim ~/.config/nvim
}

install_neovim
clone_config
