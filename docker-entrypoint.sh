#!/bin/zsh
set -e

LISTEN_IP="${LISTEN_IP:-0.0.0.0}"
LISTEN_PORT="${LISTEN_PORT:-9099}"

while true; do
    echo "[$(date)] Starting neovim server on ${LISTEN_IP}:${LISTEN_PORT}..."
    nvim --headless --listen "${LISTEN_IP}:${LISTEN_PORT}" || true
    echo "[$(date)] Neovim server stopped. Restarting in 1s..."
    sleep 1
done
