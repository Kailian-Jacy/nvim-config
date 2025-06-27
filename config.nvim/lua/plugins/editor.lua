return {
  {
    "rebelot/terminal.nvim",
    config = function()
      vim.g.__default_terminal_layout = { open_cmd = "float", height = 1, width = 1 }
      require("terminal").setup({
        layout = vim.g.__default_terminal_layout,
        cmd = { "tmux", "new", "-As0" },
        autoclose = true,
      })
      -- globally bind customized logic.
      require("terminal").__customize = {}
      require("terminal").__customize.is_currently_focusing_on_terminal = function()
        return require("terminal").current_term_index() ~= nil
      end
      require("terminal").__customize.toggle = function()
        require("terminal").toggle(0, nil, false) -- toggle as last layout.
      end
      require("terminal").__customize.reset = function()
        require("terminal").move(0, vim.g.__default_terminal_layout)
      end
      require("terminal").__customize.shift_right = function()
        vim.cmd("TermMove botright " .. math.ceil(vim.o.columns * vim.g.terminal_width_right) .. " vnew")
      end
      require("terminal").__customize.shift_left = function()
        vim.cmd("TermMove vert " .. math.ceil(vim.o.columns * vim.g.terminal_width_left) .. " vnew")
      end
      require("terminal").__customize.shift_up = function()
        vim.cmd("TermMove top " .. math.ceil(vim.o.lines * vim.g.terminal_width_top) .. " new")
      end
      require("terminal").__customize.shift_down = function()
        vim.cmd("TermMove belowright " .. math.ceil(vim.o.lines * vim.g.terminal_width_bottom) .. " new")
      end
      -- lazygit floating buffer
      local lazygit = require("terminal").terminal:new({
        layout = { open_cmd = "float", height = 1.0, width = 1.0 },
        cmd = { "lazygit" },
        autoclose = true,
      })
      -- vim.env["GIT_EDITOR"] = "nvr -cc close -cc split --remote-wait +'set bufhidden=wipe'"
      vim.api.nvim_create_user_command("Lazygit", function(args)
        lazygit.cwd = args.args and vim.fn.expand(args.args)
        lazygit:toggle(nil, true)
      end, { nargs = "?" })
      -- make gf safe in terminal buffer.
      vim.api.nvim_create_autocmd({ "TermOpen" }, {
        callback = function(args)
          if vim.startswith(vim.api.nvim_buf_get_name(args.buf), "term://") then
            vim.keymap.set("n", "gf", function()
              local f = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
              if f == "" then
                vim.print_silent("no file under cursor")
              else
                require("terminal").close()
                vim.cmd("e " .. f)
              end
            end, { buffer = true })
          end
        end,
      })
      if vim.g.terminal_auto_insert then
        vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "TermOpen" }, {
          callback = function(args)
            if vim.startswith(vim.api.nvim_buf_get_name(args.buf), "term://") then
              vim.cmd("startinsert")
            end
          end,
        })
      end
    end,
    keys = {
      {
        "<D-t>",
        function()
          require("terminal").__customize.toggle()
        end,
        mode = { "t" },
        desc = "Tmux floating toggle window terminal.",
      },
      {
        "<leader>tt",
        function()
          require("terminal").__customize.toggle()
        end,
        mode = { "n" },
        desc = "Tmux floating toggle window terminal.",
      },
      {
        "<leader>gg",
        "<cmd>Lazygit<cr>",
        mode = { "n" },
        desc = "Lazygit in floating terminal",
      },
      {
        "<c-bs>",
        function()
          require("terminal").__customize.reset()
        end,
        mode = { "t" },
        desc = "Revert and unrevert the terminal location",
      },
      {
        "<c-s-l>",
        function()
          require("terminal").__customize.shift_right()
        end,
        mode = { "t" },
        desc = "Pin the terminal to the right side.",
      },
      {
        "<c-s-h>",
        function()
          require("terminal").__customize.shift_left()
        end,
        mode = { "t" },
        desc = "Pin the terminal to the right side.",
      },
      {
        "<c-s-j>",
        function()
          require("terminal").__customize.shift_down()
        end,
        mode = { "t" },
        desc = "Pin the terminal to the right side.",
      },
      {
        "<c-s-k>",
        function()
          require("terminal").__customize.shift_up()
        end,
        mode = { "t" },
        desc = "Pin the terminal to the right side.",
      },
      {
        "<d-esc>",
        "<c-\\><c-n>",
        mode = { "t" },
        desc = "Tmux floating window terminal.",
      },
      {
        "<c-esc>",
        "<c-\\><c-n>",
        mode = { "t" },
        desc = "Tmux floating window terminal.",
      },
    },
    opts = {
      layout = { open_cmd = "float" },
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
    config = function()
      require("todo-comments").setup({})
    end,
  },
  {
    -- with lazy.nvim
    "LintaoAmons/bookmarks.nvim",
    enable = vim.g.module_enable_bookmarks,
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
