-- Local plugin: reconcile concurrent edits between you and an external agent.
-- Lives in <config>/plugins/agent-merge; loaded as a `dir` (local) plugin, never
-- cloned.
return {
  {
    "agent-merge",
    dir = vim.fn.stdpath("config") .. "/plugins/agent-merge",
    lazy = false,
    config = function()
      require("agent-merge").setup({
        load = "manual",         -- "auto" | "on_focus" | "manual"
        autosave = true,          -- pause auto-save.nvim on external change
        intercept_write = true,   -- route :w through the reconcile engine
        confirm_external = true,  -- confirm on save over an external change
        show_conflict_count = false, -- [=5] instead of [=]
        -- <leader><CR> is the composite save->format->lint mapping in
        -- plugins/lsp.lua, which calls require("agent-merge").save() first.
        save_keymap = false,
      })
    end,
  },
}
