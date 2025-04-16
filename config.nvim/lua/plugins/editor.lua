return {
  {
    "tzachar/local-highlight.nvim",
    config = function()
      require("local-highlight").setup({
        cw_hlgroup = "FaintSelected",
        hlgroup = "FaintSelected",
        animate = {
          enabled = false,
        },
        debounce_timeout = 500,
      })
    end,
  },
  {
    "kwkarlwang/bufjump.nvim",
    keys = {
      {
        "H",
        function()
          require("bufjump").backward()
        end,
        mode = "n",
        desc = "jump to last buffer.",
      },
      {
        "L",
        function()
          require("bufjump").forward()
        end,
        mode = "n",
        desc = "jump to last buffer.",
      },
    },
    config = function()
      require("bufjump").setup({})
    end,
  },
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
        require("luasnip.loaders.from_vscode").load({
          paths = vim.g.user_vscode_snippets_path,
        })
      end
    end,
  },
  {
    -- "Kailian-Jacy/visual-surround.nvim",
    "NStefan002/visual-surround.nvim",
    config = function()
      require("visual-surround").setup({
        enable_wrapped_deletion = true,
        surround_chars = { "{", "}", "[", "]", "(", ")", "'", '"', "`" },
      })

      for _, key in ipairs({ "<", ">" }) do
        vim.keymap.set("x", key, function()
          local mode = vim.api.nvim_get_mode().mode
          -- do not change the default behavior of '<' and '>' in visual-line mode
          if mode == "V" then
            return key .. "gv"
          else
            vim.schedule(function()
              require("visual-surround").surround(key)
            end)
            return "<ignore>"
          end
        end, {
          desc = "[visual-surround] Surround selection with " .. key .. " (visual mode and visual block mode)",
          expr = true,
        })
      end
    end,
  },
  {
    "vidocqh/auto-indent.nvim",
    config = function()
      -- In cmp.nvim we don't need to feed \t anymore but to use fallback to auto-indent <tab>
      -- keymap.
      vim.g._auto_indent_used = true
      require("auto-indent").setup({
        indentexpr = function(lnum)
          return require("nvim-treesitter.indent").get_indent(lnum)
        end,
      })
    end,
    opts = {},
  },
  -- {
  --   "NMAC427/guess-indent.nvim",
  --   config = function()
  --     require("guess-indent").setup({})
  --   end,
  -- },
  -- TODO: Migrate mini.pair to nvim-autopairs. At leat choose one.
  -- {
  --   "windwp/nvim-autopairs",
  --   config = function()
  --     require("nvim-autopairs").setup({
  --       event = { "BufReadPre", "BufNewFile" },
  --       opts = {
  --         enable_check_bracket_line = false, -- Don't add pairs if it already has a close pair in the same line
  --         ignored_next_char = "[%w%.]", -- will ignore alphanumeric and `.` symbol
  --         check_ts = true, -- use treesitter to check for a pair.
  --         ts_config = {
  --           lua = { "string" }, -- it will not add pair on that treesitter node
  --           javascript = { "template_string" },
  --           java = false, -- don't check treesitter on java
  --         },
  --       },
  --     })
  --   end,
  -- },
  {
    -- with lazy.nvim
    "Kailian-Jacy/bookmarks.nvim",
    -- tag = "v0.5.4", -- optional, pin the plugin at specific version for stability
    dependencies = {
      { "kkharji/sqlite.lua" },
      { "nvim-telescope/telescope.nvim" },
      -- { "stevearc/dressing.nvim" }, -- optional: to have the same UI shown in the GIF
    },
    keys = {
      -- Make it compatible as vim native.
      {
        "'",
        function()
          vim.cmd([[ BookmarkSnackPicker ]])
        end,
      },
      {
        "m", -- normal mode m for making quick note
        function()
          vim.ui.input({ prompt = "[Set Bookmark]" }, function(input)
            if input then
              local Service = require("bookmarks.domain.service")
              Service.toggle_mark("" .. input)
              require("bookmarks.sign").safe_refresh_signs()
            end
          end)
        end,
      },
      {
        "M",
        function()
          vim.cmd([[ BookmarksDesc ]])
        end,
      },
      {
        "<leader>md",
        function()
          vim.cmd([[ DeleteBookmarkAtCursor ]])
        end,
      },
      {
        "gm",
        "<cmd>BookmarksInfoCurrentBookmark<CR>",
        desc = "show bookmark information",
        mode = { "n", "v" },
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
