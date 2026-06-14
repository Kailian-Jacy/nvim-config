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
---@param session_name string
---@return table cmd
function M.build_cmd(session_name)
  -- Use tmux new-session -A: attaches if exists, creates if not.
  -- For local sessions, pass the dscc command so new sessions run it instead of a shell.
  local prefix = vim.g.floatterm_local_prefix or "nvim_local_"
  if vim.startswith(session_name, prefix) then
    return {
      "tmux", "new-session", "-As", session_name,
      "dscc", "run", session_name, "--no-worktree", "--attach", "-y",
    }
  end
  return { "tmux", "new-session", "-As", session_name }
end

return M
