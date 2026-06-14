local M = {}

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

--- Build the tmux command for termopen
--- For local sessions, runs dscc when creating a new session (not a plain shell).
--- Sources $HOME/.zprofile to ensure PATH includes dscc.
--- Writes exit status to a tmpfile so neovim can detect boot failures.
---@param session_name string
---@return table cmd, string|nil err_file
function M.build_cmd(session_name)
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
      .. 'exit $code',
      vim.fn.shellescape(session_name),
      vim.fn.shellescape(err_file)
    )
    return {
      "tmux", "new-session", "-As", session_name,
      "zsh", "-ic", shell_cmd,
    }, err_file
  end
  return { "tmux", "new-session", "-As", session_name }, nil
end

--- Install a tmux hook to forward bell events to this Neovim instance.
--- Uses tmux's `alert-bell` hook to call `nvim --server <addr> --remote-expr`.
--- Safe to call multiple times; reinstalls the hook idempotently.
---@param session_name string  the tmux session to monitor
function M.install_bell_hook(session_name)
  local addr = vim.v.servername
  if not addr or addr == "" then return end

  -- The hook fires when tmux detects a bell in the session.
  -- We call nvim_exec_lua remotely to invoke _on_term_bell_from_tmux(session_name).
  local hook_cmd = string.format(
    [[run-shell 'nvim --server %s --remote-expr "v:lua.FloatTermBellHook(\"%s\")" 2>/dev/null || true']],
    vim.fn.shellescape(addr),
    session_name:gsub('"', '\\"')
  )

  -- Remove any previous hook for this session, then set the new one
  vim.fn.system({ "tmux", "set-hook", "-t", session_name, "alert-bell", hook_cmd })
  -- Enable bell monitoring so the hook fires
  vim.fn.system({ "tmux", "set-option", "-t", session_name, "monitor-bell", "on" })
end

--- Remove the bell hook from a tmux session (cleanup).
---@param session_name string
function M.remove_bell_hook(session_name)
  vim.fn.system({ "tmux", "set-hook", "-u", "-t", session_name, "alert-bell" })
end

return M
