local M = {}
local DEFAULTS = {
  ref_prefix = "refs/subcommits", notes_prefix = "subcommits", default_session = "default",
  git_cmd = { "git" }, ssh_cmd = { "ssh", "-o", "BatchMode=yes", "-o", "ServerAliveInterval=15" },
  watch = { enabled = true, mode = "auto", poll_ms = 5000, debounce_ms = 150, reconnect_ms = 3000, remote_tail_cmd = nil },
  auto_save_before_sync = true, auto_sync_approved = false, notify_on_arrival = true,
  reviewer = {
    tab_prefix = "[track]", reuse_tab = true,
    keymaps = { next_subcommit = "]c", prev_subcommit = "[c", next_touch_file = "]f", prev_touch_file = "[f",
      approve = "<leader>ta", approve_prefix = "<leader>tA", reject = "<leader>tx", sync = "<leader>ts", panel = "<leader>tp" },
  },
  statusline = { enabled = true, format = nil }, hooks = { on_updated = nil, on_synced = nil, on_reviewed = nil },
}
local current, active_session = vim.deepcopy(DEFAULTS), nil
function M.setup(opts) current = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {}); return current end
function M.get() return current end
function M.set_active_session(s) active_session = (s and s ~= "") and s or nil end
function M.resolve_session(s)
  if type(s) == "string" and s ~= "" then return s end
  local e = vim.env.AGENT_TRACK_SESSION
  return active_session or ((e and e ~= "") and e) or current.default_session or "default"
end
function M.ref(s, name) return string.format("%s/%s/%s", (current.ref_prefix or "refs/subcommits"):gsub("/+$", ""), M.resolve_session(s), name) end
function M.notes_arg(s) return string.format("%s/%s", (current.notes_prefix or "subcommits"):gsub("^refs/notes/", ""):gsub("/+$", ""), M.resolve_session(s)) end
function M.notes_ref(s) return "refs/notes/" .. M.notes_arg(s) end
return M
