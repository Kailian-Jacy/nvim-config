-- Local plugin: reconcile concurrent edits between you and an external agent.
-- Lives in <config>/agent-merge; loaded as a `dir` (local) plugin, never cloned.
return {
  {
    "agent-merge",
    dir = vim.fn.stdpath("config") .. "/agent-merge",
    lazy = false,
    config = function()
      require("agent-merge").setup({
        load = "manual",         -- "auto" | "on_focus" | "manual"
        autosave = true,          -- pause auto-save.nvim on external change
        intercept_write = true,   -- route :w through the reconcile engine
        show_conflict_count = false, -- [=5] instead of [=]
        -- on_conflict_resolve = function(buf) ... end, -- custom resolver UI
        -- save_keymap = "<leader><cr>",
      })
    end,
  },
}
