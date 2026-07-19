local M = {}

-- ---------------------------------------------------------------------------
-- abduco session backend (replaces the previous tmux backend)
--
-- abduco is a minimal session manager (like dtach): it detaches a program from
-- its controlling terminal so it keeps running in the background and can be
-- reattached later. floatterm uses it exactly the way it used tmux sessions:
--
--   1. sessions show up in a plain `abduco` (no-arg) listing;
--   2. they survive neovim quitting/restarting (dscc-style persistence);
--   3. they can be reattached from any terminal via `abduco -a <name>`.
--
-- Unlike tmux, abduco has NO server daemon, NO multiplexing (windows/panes),
-- and NO hook/event system. See the "INCOMPATIBILITIES" note at the bottom of
-- this file for the concrete behaviour changes vs. the tmux backend.
--
-- Isolation is provided by a deterministic socket directory
-- (ABDUCO_SOCKET_DIR) plus deterministic session names
-- (`nvim_local_<cwd>` / `nvim-global`), so nothing leaks or collides.
-- Sessions are NOT killed on exit; they persist until their program exits.
-- ---------------------------------------------------------------------------

--- Return the abduco socket directory (analogue of tmux's `-S <socket>`).
--- abduco stores one unix socket per session under `<dir>/abduco/<user>/`.
--- We pin ABDUCO_SOCKET_DIR to a deterministic per-uid path so every neovim
--- and every plain-terminal `abduco -a` sees the same set of sessions.
--- Honours a pre-existing $ABDUCO_SOCKET_DIR if the user set one.
--- The value is computed once and cached.
---@return string
function M.socket_dir()
  if not M._dir then
    local env = vim.env.ABDUCO_SOCKET_DIR
    if env and #env > 0 then
      M._dir = env
    else
      local uv = vim.uv or vim.loop
      local uid = (uv and uv.getuid) and uv.getuid() or 0
      M._dir = string.format("/tmp/nvim-abduco-%d", uid)
    end
  end
  return M._dir
end

--- Ensure abduco can create sockets.
--- abduco has no server to pre-start (each `-A`/`-c` spins up its own detached
--- backend process), so this only:
---   1. exports ABDUCO_SOCKET_DIR for this neovim and all its children, and
---   2. pre-creates the directory, because abduco with an explicit
---      ABDUCO_SOCKET_DIR does NOT create a missing parent and silently falls
---      back to $HOME/.abduco otherwise.
--- Kept named `ensure_server` for API parity with the old tmux backend.
function M.ensure_server()
  local dir = M.socket_dir()
  -- Make sure children (termopen shells, D-x split, plain `abduco -a`) resolve
  -- the same socket directory.
  vim.env.ABDUCO_SOCKET_DIR = dir
  local uv = vim.uv or vim.loop
  if not (uv and uv.fs_stat(dir)) then
    -- abduco creates a user-owned `abduco/<user>` subdir with 0700 perms; the
    -- parent just needs to exist.
    vim.fn.mkdir(dir, "p", tonumber("700", 8))
  end
end

--- Generate abduco session name for the current tab based on cwd
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
  -- Keep session names free of separators abduco treats specially:
  --   '/' would make abduco interpret the name as a socket path;
  --   '@' is used by abduco to append the hostname to the socket file.
  name = name:gsub("[%.%:%s%/%@]", "_")
  local prefix = vim.g.floatterm_local_prefix or "nvim_local_"
  return prefix .. name
end

--- Get the global abduco session name
---@return string
function M.global_session_name()
  return vim.g.floatterm_global_session or "nvim-global"
end

--- Build the abduco command for termopen.
--- Uses `abduco -f -A <name> <cmd>`:
---   -A : attach if the session exists, otherwise create + attach;
---   -f : if a *terminated* session of that name lingers, recreate it
---        (so a crashed/exited shell doesn't wedge the tab forever).
--- For local sessions, runs dscc when creating a new session (not a plain
--- shell); sources $HOME/.zprofile to ensure PATH includes dscc, and writes
--- exit status to a tmpfile so neovim can detect boot failures.
---@param session_name string
---@return table cmd, string|nil err_file
function M.build_cmd(session_name)
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
    local cmd = { "abduco", "-f", "-A", session_name, "zsh", "-ic", shell_cmd }
    return cmd, err_file
  end
  local cmd = { "abduco", "-f", "-A", session_name, os.getenv("SHELL") or "zsh" }
  return cmd, nil
end

-- ---------------------------------------------------------------------------
-- Bell forwarding has no abduco equivalent — abduco has no hook/event/option
-- system (unlike tmux's alert-bell + monitor-bell), so the tab-beep-on-bell
-- feature is not implemented in this backend.
-- ---------------------------------------------------------------------------

return M
