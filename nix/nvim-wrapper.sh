#!/usr/bin/env bash
# nvim-wrapper.sh — Wrapper for nixCats-managed Neovim
#
# Usage: This wrapper is used by the Nix flake's package definition.
# It's also available for manual use:
#   ./nix/nvim-wrapper.sh [nvim args...]
#
# Or set it as your default:
#   alias nvim="$(pwd)/nix/nvim-wrapper.sh"
#
# Sets NVIM_APPNAME to ensure complete isolation from system nvim
set -euo pipefail

export NVIM_APPNAME="nvim-nix"
exec "${NVIM_NIX_BINARY:-nvim}" "$@"
