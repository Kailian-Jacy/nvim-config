local M = {}

-- ---------------------------------------------------------------------------
-- Per-nvim tmux server socket  (-S)
--
-- Each neovim instance gets its own tmux server so that:
--   1. Sessions don't collide with other nvim instances or the user's shell.
--   2. send-keys / split-window never leak into the wrong session.
--   3. Bell hooks target the correct server.
--
-- The socket lives at /tmp/nvim-floatterm-<pid>.sock and is cleaned up on
-- VimLeavePre (see floatterm/init.lua setup()).
-- ---------------------------------------------------------------------------

--- Return the tmux server socket path for this nvim instance.
--- The path is computed once and cached.
---@return string
function M.socket_path()
  if not M._socket then
    local dir = vim.fn.stdpath("run") or "/tmp"
    M._socket = string.format("%s/nvim-floatterm-%d.sock", dir, vim.fn.getpid())
  end
  return M._socket
end

--- Build the base tmux command with -S.
---@return table  base args: { "tmux", "-S", "<socket>" }
function M.base_cmd()
  return { "tmux", "-S", M.socket_path() }
end

--- Generate tmux session name for the current tab based on cwd
---@return string
function M.session_name_for_tab()
  local cwd = vim.fn.getcwd()
  -- Take last two path segments for a readable name
  local parts = vim.split(cwd, "/", { trimempty = true })
  local name
  if #parts >= 2 then
    name = parts[#parts - 1] .. "_" .. parts[#parts]
  elseif #parts >= 1 then
    name = parts[#parts]
  else
    name = "root"
  end
  -- tmux session names cannot contain . or :
  name = name:gsub("[%.%:%s]", "_")
  local prefix = vim.g.floatterm_local_prefix or "nvim_local_"
  return prefix .. name
end

--- Get the global tmux session name
---@return string
function M.global_session_name()
  return vim.g.floatterm_global_session or "nvim-global"
end

--- Build the tmux command for termopen.
--- Every invocation includes ``-S <socket>`` so the session lives on
--- this neovim's dedicated tmux server.
--- For local sessions, runs dscc when creating a new session (not a plain shell).
--- Sources $HOME/.zprofile to ensure PATH includes dscc.
--- Writes exit status to a tmpfile so neovim can detect boot failures.
---@param session_name string
---@return table cmd, string|nil err_file
function M.build_cmd(session_name)
  local base = M.base_cmd()
  -- Use tmux new-session -A: attaches if exists, creates if not.
  -- For local sessions, wrap in a login shell that sources .zprofile for PATH,
  -- then execs dscc. On failure, write error to a tmpfile for neovim to read.
  local prefix = vim.g.floatterm_local_prefix or "nvim_local_"
  if vim.startswith(session_name, prefix) then
    local err_file = vim.fn.tempname() .. ".floatterm_err"
    local shell_cmd = string.format(
      '[ -f "$HOME/.zprofile" ] && . "$HOME/.zprofile"; '
      .. 'dscc run %s --no-worktree --attach -y; '
      .. 'code=$?; '
      .. 'if [ $code -ne 0 ]; then '
      ..   'echo "dscc exited with code $code" > %s; '
      .. 'fi; '
      .. 'exec zsh',
      vim.fn.shellescape(session_name),
      vim.fn.shellescape(err_file)
    )
    local cmd = vim.list_extend(vim.deepcopy(base), {
      "new-session", "-As", session_name,
      "zsh", "-ic", shell_cmd,
    })
    return cmd, err_file
  end
  local cmd = vim.list_extend(vim.deepcopy(base), { "new-session", "-As", session_name })
  return cmd, nil
end

--- Install a tmux hook to forward bell events to this Neovim instance.
--- Uses tmux's `alert-bell` hook to call `nvim --server <addr> --remote-expr`.
--- Safe to call multiple times; reinstalls the hook idempotently.
---@param session_name string  the tmux session to monitor
function M.install_bell_hook(session_name)
  local addr = vim.v.servername
  if not addr or addr == "" then return end

  local sock = M.socket_path()

  -- The hook fires when tmux detects a bell in the session.
  -- We call nvim_exec_lua remotely to invoke _on_term_bell_from_tmux(session_name).
  local hook_cmd = string.format(
    [[run-shell 'nvim --server %s --remote-expr "v:lua.FloatTermBellHook(\"%s\")" 2>/dev/null || true']],
    vim.fn.shellescape(addr),
    session_name:gsub('"', '\\"')
  )

  -- Remove any previous hook for this session, then set the new one
  local base = M.base_cmd()
  vim.fn.system(vim.list_extend(vim.deepcopy(base), { "set-hook", "-t", session_name, "alert-bell", hook_cmd }))
  -- Enable bell monitoring so the hook fires
  vim.fn.system(vim.list_extend(vim.deepcopy(base), { "set-option", "-t", session_name, "monitor-bell", "on" }))
end

--- Remove the bell hook from a tmux session (cleanup).
---@param session_name string
function M.remove_bell_hook(session_name)
  local base = M.base_cmd()
  vim.fn.system(vim.list_extend(vim.deepcopy(base), { "set-hook", "-u", "-t", session_name, "alert-bell" }))
end

--- Kill the dedicated tmux server and remove the socket file.
--- Called on VimLeavePre to clean up.
function M.kill_server()
  local sock = M.socket_path()
  vim.fn.system({ "tmux", "-S", sock, "kill-server" })
  pcall(vim.fn.delete, sock)
end

return M
