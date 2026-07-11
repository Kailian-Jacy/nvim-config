-- Local plugin: reconcile concurrent edits between you and an external agent.
-- Lives in <config>/agent-merge; loaded as a `dir` (local) plugin, never cloned.
return {
  {
    "agent-merge",
    dir = vim.fn.stdpath("config") .. "/agent-merge",
    lazy = false,
    config = function()
      require("agent-merge").setup({
        -- poll_ms = 2000,  -- fs_poll fallback interval (default 2000)
      })
    end,
  },
}
