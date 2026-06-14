return {
  {
    -- Floating terminal system (replaces terminal.nvim)
    -- Pure neovim API: dual terminal (global + local) with slot positioning
    dir = vim.fn.stdpath("config") .. "/lua/config/floatterm",
    name = "floatterm",
    virtual = true,
    config = function()
      require("config.floatterm").setup()
    end,
    keys = {
      -- Toggle global terminal
      {
        "<D-t>",
        function() require("config.floatterm").toggle_global() end,
        mode = { "n", "v", "t" },
        desc = "Toggle global floating terminal",
      },
      {
        "<leader>tt",
        function() require("config.floatterm").toggle_global() end,
        mode = { "n" },
        desc = "Toggle global floating terminal",
      },
      -- Toggle local terminal
      {
        "<D-a>",
        function() require("config.floatterm").toggle_local() end,
        mode = { "n", "v", "t" },
        desc = "Toggle local floating terminal",
      },
      {
        "<leader>aa",
        function() require("config.floatterm").toggle_local() end,
        mode = { "n" },
        desc = "Toggle local floating terminal",
      },
      -- Shift position
      {
        "<c-s-h>",
        function() require("config.floatterm").shift_position("h") end,
        mode = { "t" },
        desc = "Shift terminal to left slot",
      },
      {
        "<c-s-l>",
        function() require("config.floatterm").shift_position("l") end,
        mode = { "t" },
        desc = "Shift terminal to right slot",
      },
      {
        "<c-s-j>",
        function() require("config.floatterm").shift_position("j") end,
        mode = { "t" },
        desc = "Shift terminal to centered slot",
      },
      {
        "<c-s-k>",
        function() require("config.floatterm").shift_position("k") end,
        mode = { "t" },
        desc = "Shift terminal to centered slot",
      },
      -- Reset position (cmd-del in terminal mode)
      {
        "<c-bs>",
        function() require("config.floatterm").reset_position() end,
        mode = { "t" },
        desc = "Reset terminal position to centered",
      },
      -- Close floating terminal
      {
        "<C-/>",
        function()
          local ft = require("config.floatterm")
          local inst = ft.get_focused_terminal()
          if inst then ft.hide(inst) end
        end,
        mode = { "t" },
        desc = "Hide floating terminal",
      },
      -- Escape terminal mode
      {
        "<d-esc>",
        "<c-\\><c-n>",
        mode = { "t" },
        desc = "Exit terminal insert mode",
      },
      {
        "<c-esc>",
        "<c-\\><c-n>",
        mode = { "t" },
        desc = "Exit terminal insert mode",
      },
      -- Lazygit
      {
        "<leader>gg",
        "<cmd>Lazygit<cr>",
        mode = { "n" },
        desc = "Lazygit in floating terminal",
      },
    },
  },
  {
    "tzachar/local-highlight.nvim",
    opts = {
      disable_file_types = { "help" },
      cw_hlgroup = "FaintSelected",
      hlgroup = "FaintSelected",
      animate = {
        enabled = true,
        easing = "linear",
        duration = {
          step = 7, -- ms per step
          total = 30, -- maximum duration
          fps = 120,
        },
      },
      highlight_single_match = true,
      debounce_timeout = 300,
    },
  },
  {
    "kwkarlwang/bufjump.nvim",
    keys = {
      {
        "H",
        function()
          require("bufjump").backward()
          -- if terminal, jump one more.
          if vim.startswith(vim.api.nvim_buf_get_name(0), "term://") then
            require("bufjump").backward()
          end
        end,
        mode = "n",
        desc = "jump to last buffer.",
      },
      {
        "L",
        function()
          require("bufjump").forward()
          -- if terminal, jump one more.
          if vim.startswith(vim.api.nvim_buf_get_name(0), "term://") then
            require("bufjump").backward()
          end
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
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    config = function()
      -- keymaps are all configured at nvim-cmp.
      require("luasnip.loaders.from_vscode").lazy_load((
        function ()
          if vim.g.import_user_snippets then
            return {
              paths = vim.g.user_vscode_snippets_path,
            }
          else
            return {}
          end
        end
      )())
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
          -- Neovim 0.12: nvim-treesitter.indent was removed;
          -- use the new indentexpr() from nvim-treesitter main branch.
          -- indentexpr() reads vim.v.lnum internally, so set it first.
          vim.v.lnum = lnum
          return require("nvim-treesitter").indentexpr()
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
    "folke/todo-comments.nvim",
    keys = {
      {
        "<leader>mt",
        function()
          local text = "TODO: zianxu"
          if vim.tbl_contains({ "v", "V", "s" }, vim.fn.mode()) then
            local selected_content = vim.g.function_get_selected_content()
            if #selected_content then
              text = text .. ": " .. selected_content
            end
          end
          vim.api.nvim_feedkeys("O" .. text, "n", false)
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
          vim.api.nvim_feedkeys("gcc", "m", false)
        end,
        mode = { "n", "v" },
        desc = "add todo mark at this line.",
      },
    },
    opts = {
      signs = false,
      keywords = {
        CHECK = { color = "warning" },
        BUGREPORT = { color = "warning" }
      },
    },
  },
  {
    -- with lazy.nvim
    "LintaoAmons/bookmarks.nvim",
    enabled = vim.g.modules.bookmarks and vim.g.modules.bookmarks.enabled,
    -- tag = "v0.5.4", -- optional, pin the plugin at specific version for stability
    dependencies = {
      { "kkharji/sqlite.lua" },
      -- { "nvim-telescope/telescope.nvim" },
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
        "<leader>mm",
        function()
          vim.cmd([[ BookmarkGrepMarkedFiles ]])
        end,
        mode = { "n", "v" },
        desc = "grep across bookmarked files.",
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
