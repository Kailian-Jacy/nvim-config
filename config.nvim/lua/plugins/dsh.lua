-- Local plugin: the DeepSeek Harness ⇄ neovim bridge.
-- Lives in <config>/plugins/dsh.nvim; loaded as a `dir` (local) plugin, never
-- cloned.
--
-- Lazy on purpose: it costs nothing at startup. It loads when a Walkthrough
-- command is used, or — since lazy.nvim installs a module searcher — the first
-- time anything requires `dsh.*`, which is how the agent triggers it over the
-- RPC socket without needing a command.
return {
  {
    "dsh.nvim",
    dir = vim.fn.stdpath("config") .. "/plugins/dsh.nvim",
    lazy = true,
    cmd = {
      "Walkthrough",
      "WalkthroughOpen",
      "WalkthroughValidate",
      "WalkthroughClose",
      "WalkthroughReload",
      "WalkthroughLayer",
    },
    config = function()
      require("dsh").setup({
        walkthrough = {
          -- 58 is the narrowest panel where a 50-column code line still fits
          -- the inset card without truncation.
          panel_width = 58,
          keys = {
            next = "<leader>qj",
            prev = "<leader>qk",
            toggle_panel = "<leader>qq",
            layer = "<leader>qi",
          },
          -- These override the quickfix maps of the same name while a
          -- walkthrough is active, and are restored by :WalkthroughClose.
        },
      })
    end,
  },
}
