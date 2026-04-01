#!/usr/bin/env bash
# verify-isolation.sh — Verify that original nvim and nvim-nix are fully isolated
# Checks XDG directories, shada files, plugins, and stdpath() output
set -euo pipefail

# --- Platform-aware paths ---
if [[ "$(uname -s)" == "Darwin" ]]; then
  CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}"
  DATA_BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
  STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
  CACHE_BASE="${HOME}/Library/Caches"
else
  CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}"
  DATA_BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
  STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
  CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}"
fi

PASS=0
FAIL=0
WARN=0

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠️  WARN: $1"; WARN=$((WARN + 1)); }

check_dir_isolation() {
  local label="$1"
  local base="$2"
  local dir_orig="$base/nvim"
  local dir_nix="$base/nvim-nix"

  echo ""
  echo "--- $label ---"
  echo "  Original: $dir_orig"
  echo "  NixCats:  $dir_nix"

  if [ -d "$dir_orig" ] && [ -d "$dir_nix" ]; then
    if [ "$dir_orig" != "$dir_nix" ]; then
      pass "$label directories are separate"
    else
      fail "$label directories point to the same path!"
    fi
  elif [ -d "$dir_orig" ] && [ ! -d "$dir_nix" ]; then
    warn "$label: nvim-nix directory doesn't exist yet (will be created on first run)"
  elif [ ! -d "$dir_orig" ] && [ -d "$dir_nix" ]; then
    warn "$label: original nvim directory doesn't exist"
  else
    warn "$label: neither directory exists yet"
  fi
}

check_shada_isolation() {
  echo ""
  echo "--- ShaDa Files ---"
  local shada_orig="$STATE_BASE/nvim/shada/main.shada"
  local shada_nix="$STATE_BASE/nvim-nix/shada/main.shada"

  echo "  Original: $shada_orig"
  echo "  NixCats:  $shada_nix"

  if [ -f "$shada_orig" ] && [ -f "$shada_nix" ]; then
    if [ "$shada_orig" != "$shada_nix" ]; then
      pass "ShaDa files are separate"
      # Check they're actually different files (not hardlinks)
      if [ "$(stat -c '%i' "$shada_orig" 2>/dev/null || stat -f '%i' "$shada_orig" 2>/dev/null)" != \
           "$(stat -c '%i' "$shada_nix" 2>/dev/null || stat -f '%i' "$shada_nix" 2>/dev/null)" ]; then
        pass "ShaDa files are different inodes (not hardlinked)"
      else
        warn "ShaDa files share the same inode — they may be hardlinked!"
      fi
    else
      fail "ShaDa files point to the same path!"
    fi
  else
    warn "One or both ShaDa files don't exist yet (created on first nvim run)"
  fi
}

check_plugin_isolation() {
  echo ""
  echo "--- Plugin Directories ---"
  local plugins_orig="$DATA_BASE/nvim/lazy"
  local plugins_nix="$DATA_BASE/nvim-nix/lazy"

  echo "  Original (lazy.nvim): $plugins_orig"
  echo "  NixCats (lazy/nix):   $plugins_nix"

  if [ -d "$plugins_orig" ]; then
    local count_orig
    count_orig=$(ls -1 "$plugins_orig" 2>/dev/null | wc -l)
    echo "  Original plugins: $count_orig"
  else
    echo "  Original plugins: (directory not found)"
  fi

  if [ -d "$plugins_nix" ]; then
    local count_nix
    count_nix=$(ls -1 "$plugins_nix" 2>/dev/null | wc -l)
    echo "  NixCats plugins: $count_nix"
  else
    echo "  NixCats plugins: (directory not found — nixCats may manage plugins via Nix store)"
  fi

  if [ -d "$plugins_orig" ] && [ -d "$plugins_nix" ]; then
    pass "Plugin directories are separate"
  else
    warn "Can't fully verify plugin isolation (one or both directories missing)"
  fi
}

check_stdpath() {
  local nvim_bin="${1:-nvim}"
  local nvim_nix_bin="${2:-nvim-nix}"

  echo ""
  echo "Checking runtime stdpath..."

  if command -v "$nvim_bin" &>/dev/null; then
    stdpath_orig=$("$nvim_bin" --headless -c 'lua print(vim.fn.stdpath("data"))' -c 'qa!' 2>/dev/null) || true
    echo "  Original nvim data: $stdpath_orig"
  else
    warn "Original nvim ($nvim_bin) not found, skipping stdpath comparison"
    return
  fi

  if command -v "$nvim_nix_bin" &>/dev/null; then
    stdpath_nix=$("$nvim_nix_bin" --headless -c 'lua print(vim.fn.stdpath("data"))' -c 'qa!' 2>/dev/null) || true
    echo "  NixCats nvim data: $stdpath_nix"
  else
    warn "NixCats nvim ($nvim_nix_bin) not found, skipping stdpath comparison"
    return
  fi

  if [ -n "$stdpath_orig" ] && [ -n "$stdpath_nix" ] && [ "$stdpath_orig" != "$stdpath_nix" ]; then
    pass "Runtime stdpath('data') differs between versions"
  else
    fail "Runtime stdpath('data') is the same or empty"
  fi
}

# --- Main ---

echo "╔══════════════════════════════════════════════════╗"
echo "║   Neovim Dual-Version Isolation Verification     ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Checking isolation between nvim (original) and nvim-nix (nixCats)..."
echo "Platform: $(uname -s) $(uname -m)"

check_dir_isolation "Config"  "$CONFIG_BASE"
check_dir_isolation "Data"    "$DATA_BASE"
check_dir_isolation "State"   "$STATE_BASE"
check_dir_isolation "Cache"   "$CACHE_BASE"
check_shada_isolation
check_plugin_isolation
check_stdpath "${1:-nvim}" "${2:-nvim-nix}"

echo ""
echo "════════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "⚠️  Some isolation checks FAILED. Review the output above."
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo ""
  echo "All checks passed, but some directories don't exist yet."
  echo "Run both nvim versions at least once to create them, then re-verify."
  exit 0
else
  echo ""
  echo "✅ Full isolation confirmed!"
  exit 0
fi
