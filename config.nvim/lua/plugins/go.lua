return {
  {
    "ray-x/go.nvim",
    dependencies = { -- optional packages
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup({
        dap_debug_gui = false,
      })
    end,
    event = { "CmdlineEnter" },
    ft = { "go", "gomod" },
    -- In Nix, Go tools are provided by Nix; skip Mason/go.install build step.
    build = (vim.g.nixCats ~= nil) and nil or ':lua require("go.install").update_all_sync()',
  },
}
