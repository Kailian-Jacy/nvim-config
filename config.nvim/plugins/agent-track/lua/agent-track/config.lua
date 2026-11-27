local M = {}
local function ensure_ssh_dir()
  local dir = ((vim.env.XDG_RUNTIME_DIR and vim.env.XDG_RUNTIME_DIR ~= "") and vim.env.XDG_RUNTIME_DIR or ("/tmp/nvim-" .. ((vim.env.USER and vim.env.USER ~= "") and vim.env.USER or "user"))):gsub("/+$", "")
  pcall(vim.fn.mkdir, dir, "p", "0700")
  return dir
end
local function default_ssh_cmd()
  return { "ssh", "-o", "BatchMode=yes", "-o", "ControlMaster=auto", "-o", "ControlPath=" .. ensure_ssh_dir() .. "/at-ssh-%C", "-o", "ControlPersist=600", "-o", "ServerAliveInterval=30" }
end
local DEFAULTS = {
  ref_prefix = "refs/subcommits", notes_prefix = "subcommits", default_session = "default",
  git_cmd = { "git" },
  ssh_cmd = default_ssh_cmd(),
  watch = { enabled = true, mode = "auto", poll_ms = 5000, ssh_poll_ms = 0, debounce_ms = 150, reconnect_ms = 3000, max_retries = 3, remote_tail_cmd = nil },
  auto_save_before_sync = true, auto_sync_approved = false, notify_on_arrival = true,
  reviewer = {
    tab_prefix = "[track]", reuse_tab = true, open_on_attach = true, -- :AgentTrack attach opens the first pending subcommit
    pane = { enabled = true, position = "bottom", max_height = 5 }, -- subcommit list: full-width bottom ("explorer": under the file tree)
    keymaps = { next_subcommit = { "<D-j>", "<leader>tj", "]c" }, prev_subcommit = { "<D-k>", "<leader>tk", "[c" },
      next_file = "J", prev_file = "K", next_touch_file = "]f", prev_touch_file = "[f", approve = { "A", "<leader>ta" }, approve_comment = "<leader>tc",
      approve_prefix = "<leader>tA", reject = { "R", "<leader>tx" }, sync = "<leader>ts", panel = "<leader>tp",
      comment = { "m", "<leader>tq" }, toggle_explorer = "b", toggle_pane = "c" },
  },
  statusline = { enabled = true, format = nil }, hooks = { on_updated = nil, on_synced = nil, on_reviewed = nil },
}
local current, active_session, user_opts = vim.deepcopy(DEFAULTS), nil, nil
function M.setup(opts)
  user_opts = opts and vim.deepcopy(opts) or nil
  DEFAULTS.ssh_cmd = default_ssh_cmd()
  current = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {})
  return current
end
function M.get() return current end
function M.get_user_opts() return user_opts end
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
