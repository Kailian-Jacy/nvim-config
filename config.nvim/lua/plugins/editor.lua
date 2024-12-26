return {
  {
    "L3MON4D3/LuaSnip",
    -- follow latest release.
    version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
    -- install jsregexp (optional!).
    build = "make install_jsregexp",
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function()
      -- keymaps are all configured at nvim-cmp.
      require("luasnip.loaders.from_vscode").lazy_load()
      if vim.g.import_user_snippets then
        require("luasnip.loaders.from_vscode").load({ paths = { vim.g.user_vscode_snippets_path } })
      end
    end,
  },
  {
    "NStefan002/visual-surround.nvim",
    config = true,
  },
  -- Now replaced with simpler plugin
  --[[{
    "kylechui/nvim-surround",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- Configuration here, or leave empty to use defaults
        keymaps = {
          visual = 's',
          visual_line = 'S'
        }
      })
    end
  },]]
  {
    "vidocqh/auto-indent.nvim",
    config = function()
      require("auto-indent").setup({
        indentexpr = function(lnum)
          return require("nvim-treesitter.indent").get_indent(lnum)
        end,
      })
    end,
    opts = {},
  },
}
