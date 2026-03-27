-- Floating window solution: noice.nvim
-- Replaces default cmdline, messages, and notifications with floating UI.
-- Addresses nvim-config#6: A more efficient, powerful and responsive floating window solution.
return {
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      -- Optional: better notification rendering (already used by snacks, keep as fallback)
      -- "rcarriga/nvim-notify",
    },
    keys = {
      {
        "<leader>im",
        function()
          require("noice").cmd("history")
        end,
        desc = "Noice: Message History",
      },
      {
        "<leader>il",
        function()
          require("noice").cmd("last")
        end,
        desc = "Noice: Last Message",
      },
      {
        "<leader>ie",
        function()
          require("noice").cmd("errors")
        end,
        desc = "Noice: Error Messages",
      },
      {
        "<leader>id",
        function()
          require("noice").cmd("dismiss")
        end,
        desc = "Noice: Dismiss All",
      },
    },
    opts = {
      -- Cmdline: floating popup at the center-top of the screen.
      cmdline = {
        enabled = true,
        view = "cmdline_popup",
        opts = {},
        format = {
          cmdline = { pattern = "^:", icon = "", lang = "vim" },
          search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
          search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
          filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
          lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
          help = { pattern = "^:%s*he?l?p?%s+", icon = "󰋖" },
          input = { view = "cmdline_popup", icon = "󰥻 " },
        },
      },
      -- Messages: show in a minimal floating window.
      messages = {
        enabled = true,
        view = "notify",        -- default view for messages
        view_error = "notify",  -- errors
        view_warn = "notify",   -- warnings
        view_history = "messages", -- :messages view
        view_search = "virtualtext", -- search count in virtualtext
      },
      -- Popupmenu: use nui backend for better compatibility with cmdline_popup.
      popupmenu = {
        enabled = true,
        backend = "nui",
      },
      -- Notifications: use noice built-in (mini view).
      notify = {
        enabled = true,
        view = "notify",
      },
      -- LSP integration: override vim.lsp.util.convert_input_to_markdown_lines,
      -- vim.lsp.util.stylize_markdown, and cmp documentation.
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        -- Show LSP progress in a subtle notification.
        progress = {
          enabled = true,
          view = "mini",
        },
        -- Hover and signature help in floating windows.
        hover = {
          enabled = true,
          silent = true, -- don't show "No information available" message
        },
        signature = {
          enabled = true,
          auto_open = {
            enabled = true,
            trigger = true,
            luasnip = true,
            throttle = 50,
          },
        },
        message = {
          enabled = true,
          view = "notify",
        },
      },
      -- Presets: enable some nice defaults.
      presets = {
        bottom_search = false,        -- use floating search popup
        command_palette = true,        -- position cmdline and popupmenu together
        long_message_to_split = true,  -- long messages go to split
        inc_rename = true,             -- input dialog for inc-rename.nvim
        lsp_doc_border = true,         -- add border to hover docs and signature help
      },
      -- Routes: filter out some noisy messages.
      routes = {
        -- Skip "written" messages.
        {
          filter = {
            event = "msg_show",
            kind = "",
            find = "written",
          },
          opts = { skip = true },
        },
        -- Skip search count messages (shown in virtualtext already).
        {
          filter = {
            event = "msg_show",
            kind = "search_count",
          },
          opts = { skip = true },
        },
        -- Route long messages to a split.
        {
          filter = {
            event = "msg_show",
            min_height = 10,
          },
          view = "split",
        },
      },
      -- Views configuration.
      views = {
        -- Cmdline popup: centered at the top.
        cmdline_popup = {
          position = {
            row = "40%",
            col = "50%",
          },
          size = {
            width = 60,
            height = "auto",
          },
          border = {
            style = "rounded",
            padding = { 0, 1 },
          },
          win_options = {
            winhighlight = {
              Normal = "NormalFloat",
              FloatBorder = "FloatBorder",
            },
          },
        },
        -- Mini: bottom-right notifications (for LSP progress, etc).
        mini = {
          timeout = 3000,
          zindex = 50,
        },
      },
    },
    config = function(_, opts)
      require("noice").setup(opts)

      -- Since noice handles messages, we can enable snacks.notify
      -- as a fallback renderer or disable it to avoid conflicts.
      -- noice.nvim takes priority over snacks.notifier when both are loaded.
    end,
  },
}
