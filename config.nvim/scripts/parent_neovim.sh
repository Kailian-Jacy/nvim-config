#!/bin/sh
# parent_neovim.sh — Outputs RPC socket(s) of neovim instance(s) attached to the current tmux session.
# One socket path per line.
#
# Usage:
#   ${XDG_CONFIG_HOME:-$HOME/.config}/nvim/scripts/parent_neovim.sh | xargs -I{} nvim --server {} --remote-send ':lua vim.notify("Hello World")<CR>'

SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null)
if [ -z "$SESSION" ]; then
  exit 1
fi

# Platform-specific helpers
get_ppid() {
  ps -o ppid= -p "$1" 2>/dev/null | tr -d ' '
}

get_comm() {
  ps -o comm= -p "$1" 2>/dev/null | xargs basename 2>/dev/null
}

get_nvim_socket() {
  # Find the RPC unix socket for an nvim process
  local npid="$1"
  local sock=""

  # Method 1: parse --listen from cmdline (works if explicitly set)
  if [ -d "/proc/$npid" ]; then
    sock=$(tr '\0' '\n' < /proc/"$npid"/cmdline 2>/dev/null | grep -A1 -- '--listen' | tail -1)
  else
    sock=$(ps -o args= -p "$npid" 2>/dev/null | tr ' ' '\n' | grep -A1 -- '--listen' | tail -1)
  fi

  # Validate it's actually a socket path (not another flag)
  if [ -n "$sock" ] && [ -S "$sock" ]; then
    echo "$sock"
    return
  fi

  # Method 2: use lsof to find unix domain sockets owned by the nvim process
  # nvim's RPC socket path typically contains "nvim" in the path
  sock=$(lsof -U -p "$npid" -a -F n 2>/dev/null | grep '^n/' | sed 's/^n//' | grep nvim | head -1)
  if [ -n "$sock" ] && [ -S "$sock" ]; then
    echo "$sock"
    return
  fi

  # Method 3: check XDG_RUNTIME_DIR or /tmp for nvim.<pid>.0 pattern (nvim 0.9+)
  for candidate in \
    "${XDG_RUNTIME_DIR:-/tmp}/nvim.${npid}.0" \
    "/tmp/nvim.${npid}.0" \
    "${TMPDIR:-/tmp}/nvim.${npid}.0"; do
    if [ -S "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done

  # Method 4: broader lsof search (any unix socket, not just ones with "nvim" in path)
  sock=$(lsof -U -p "$npid" -a -F n 2>/dev/null | grep '^n/' | sed 's/^n//' | head -1)
  if [ -n "$sock" ] && [ -S "$sock" ]; then
    echo "$sock"
    return
  fi

  return 1
}

# 1. Find all nvim PIDs attached to this tmux session
NVIM_PIDS=""
for cpid in $(tmux list-clients -t "$SESSION" -F '#{client_pid}'); do
  pid=$cpid
  while [ "$pid" != "1" ] && [ "$pid" != "0" ] && [ -n "$pid" ]; do
    comm=$(get_comm "$pid")
    if [ "$comm" = "nvim" ]; then
      # Deduplicate
      case " $NVIM_PIDS " in
        *" $pid "*) ;;
        *) NVIM_PIDS="$NVIM_PIDS $pid" ;;
      esac
      break
    fi
    pid=$(get_ppid "$pid")
  done
done

# Output sockets
for npid in $NVIM_PIDS; do
  get_nvim_socket "$npid"
done
