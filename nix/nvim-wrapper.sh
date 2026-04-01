#!/usr/bin/env bash
# Wrapper script for nixCats-managed Neovim
# Sets NVIM_APPNAME to ensure complete isolation from system nvim
set -euo pipefail

export NVIM_APPNAME="nvim-nix"
exec "${NVIM_NIX_BINARY:-nvim}" "$@"
