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
    -- "Kailian-Jacy/visual-surround.nvim",
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
  {
    "NMAC427/guess-indent.nvim",
    config = function()
      require("guess-indent").setup({})
    end,
  },
  -- TODO: Migrate mini.pair to nvim-autopairs. At leat choose one.
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup({
        event = { "BufReadPre", "BufNewFile" },
        opts = {
          enable_check_bracket_line = false, -- Don't add pairs if it already has a close pair in the same line
          ignored_next_char = "[%w%.]", -- will ignore alphanumeric and `.` symbol
          check_ts = true, -- use treesitter to check for a pair.
          ts_config = {
            lua = { "string" }, -- it will not add pair on that treesitter node
            javascript = { "template_string" },
            java = false, -- don't check treesitter on java
          },
        },
      })
    end,
  },
  {
    -- with lazy.nvim
    "Kailian-Jacy/bookmarks.nvim",
    -- tag = "v0.5.4", -- optional, pin the plugin at specific version for stability
    dependencies = {
      { "kkharji/sqlite.lua" },
      { "nvim-telescope/telescope.nvim" },
      { "stevearc/dressing.nvim" }, -- optional: to have the same UI shown in the GIF
    },
    keys = {
      {
        "<leader>ll",
        function()
          vim.cmd([[ BookmarksLists ]])
        end,
      },
      {
        "<leader>lL",
        function()
          vim.cmd([[ BookmarksNewList ]])
        end,
      },
      {
        "<leader>jj",
        function()
          vim.ui.input({ prompt = "[Set Bookmark]" }, function(input)
            if input then
              local Service = require("bookmarks.domain.service")
              Service.toggle_mark("[BM]" .. input)
              require("bookmarks.sign").safe_refresh_signs()
            end
          end)
        end,
      },
      {
        "<leader>jJ",
        function()
          vim.cmd([[ BookmarksDesc ]])
        end,
      },
    },
    commands = {
      mark_comment = function()
        vim.ui.input({ prompt = "[Set Bookmark]" }, function(input)
          if input then
            local Service = require("bookmarks.domain.service")
            Service.toggle_mark("[BM]" .. input)
            require("bookmarks.sign").safe_refresh_signs()
          end
        end)
      end,
    },
    config = function()
      local opts = {}
      require("bookmarks").setup(opts)
    end,
  },
}
