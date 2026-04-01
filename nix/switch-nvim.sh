#!/usr/bin/env bash
# switch-nvim.sh — Switch default neovim between original and nixCats-managed version
# Usage:
#   ./switch-nvim.sh status    — Show which version is currently the default
#   ./switch-nvim.sh nix       — Set nvim-nix (nixCats) as the default `nvim`
#   ./switch-nvim.sh original  — Restore original nvim as the default
set -euo pipefail

# --- Constants ---
MARKER_START="# nixcats-switch-start"
MARKER_END="# nixcats-switch-end"
ALIAS_LINE='alias nvim="nvim-nix"'

# --- Helpers ---

get_rc_files() {
  RC_FILES=()
  if [ -f "$HOME/.bashrc" ]; then
    RC_FILES+=("$HOME/.bashrc")
  fi
  if [ -f "$HOME/.zshrc" ]; then
    RC_FILES+=("$HOME/.zshrc")
  fi
  # If neither exists, default to .bashrc
  if [ ${#RC_FILES[@]} -eq 0 ]; then
    RC_FILES+=("$HOME/.bashrc")
  fi
}

has_alias_block() {
  local rc_file="$1"
  grep -qF "$MARKER_START" "$rc_file" 2>/dev/null
}

add_alias_block() {
  local rc_file="$1"
  if has_alias_block "$rc_file"; then
    # Already present — idempotent
    return 0
  fi
  {
    echo ""
    echo "$MARKER_START"
    echo '# Managed by switch-nvim.sh — do not edit manually'
    echo "$ALIAS_LINE"
    echo "$MARKER_END"
  } >> "$rc_file"
  echo "  ✓ Added nvim alias to $(basename "$rc_file")"
}

remove_alias_block() {
  local rc_file="$1"
  if ! has_alias_block "$rc_file"; then
    # Not present — idempotent
    return 0
  fi
  # Use sed to remove the block
  local SED_SUFFIX=""
  if [[ "$(uname -s)" == "Darwin" ]]; then
    SED_SUFFIX=" ''"
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "/$MARKER_START/,/$MARKER_END/d" "$rc_file"
  else
    sed -i "/$MARKER_START/,/$MARKER_END/d" "$rc_file"
  fi
  # Clean up consecutive blank lines left after removal
  sed -i${SED_SUFFIX} '/^$/N;/^\n$/d' "$rc_file" 2>/dev/null || true
  echo "  ✓ Removed nvim alias from $(basename "$rc_file")"
}

# --- Commands ---

cmd_status() {
  echo "=== Neovim Version Status ==="
  echo ""

  # Check shell aliases
  local nix_is_default=false
  get_rc_files
  for rc_file in "${RC_FILES[@]}"; do
    if has_alias_block "$rc_file"; then
      echo "  $(basename "$rc_file"): nvim → nvim-nix (nixCats is default)"
      nix_is_default=true
    else
      echo "  $(basename "$rc_file"): nvim → original"
    fi
  done

  echo ""
  if $nix_is_default; then
    echo "Current default: nixCats (nvim-nix)"
    echo "  Run './switch-nvim.sh original' to switch back"
  else
    echo "Current default: original nvim"
    echo "  Run './switch-nvim.sh nix' to switch to nixCats"
  fi

  echo ""
  echo "Direct access (always available):"
  echo "  nvim       — original neovim (unless aliased)"
  echo "  nvim-nix   — nixCats-managed neovim"
  echo "  NVIM_APPNAME=nvim-nix nvim  — manual isolation"
}

cmd_nix() {
  echo "Switching default nvim → nixCats (nvim-nix)..."
  get_rc_files
  for rc_file in "${RC_FILES[@]}"; do
    add_alias_block "$rc_file"
  done
  echo ""
  echo "Done! Restart your shell or run: source ~/.bashrc  (or ~/.zshrc)"
  echo "  nvim     → will now launch nvim-nix (nixCats)"
  echo "  command nvim  → still accesses original nvim"
}

cmd_original() {
  echo "Switching default nvim → original..."
  get_rc_files
  for rc_file in "${RC_FILES[@]}"; do
    remove_alias_block "$rc_file"
  done
  echo ""
  echo "Done! Restart your shell or run: source ~/.bashrc  (or ~/.zshrc)"
  echo "  nvim     → original neovim"
}

# --- Main ---

case "${1:-help}" in
  status)
    cmd_status
    ;;
  nix)
    cmd_nix
    ;;
  original|orig|restore)
    cmd_original
    ;;
  help|--help|-h)
    echo "Usage: $0 {status|nix|original}"
    echo ""
    echo "Commands:"
    echo "  status    Show which neovim version is the current default"
    echo "  nix       Set nvim-nix (nixCats) as the default 'nvim'"
    echo "  original  Restore original nvim as the default"
    exit 0
    ;;
  *)
    echo "Error: Unknown command '$1'"
    echo "Usage: $0 {status|nix|original}"
    exit 1
    ;;
esac
