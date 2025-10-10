return {
  {
    "Mofiqul/dracula.nvim",
    config = function()
      require("dracula").setup({
        colors = {
          -- selection = "#0F3460",
          selection = "#2D4263",
          visual = "#2D4263",
          bg = "#13103d",
        },
        -- Transparent is not controlled at neovim layer. "transparent" here is just to clear some of the background group.
        -- if transprent bg set, the background hl just goes transparent, but linked hl
        --  (telescope, etc) remains.
        -- and the bottom gui/terminal take control.
        -- dracula can only make full transparency or not. Not semi. So just set it to none. transparent_bg = true,
        italic_comment = true,
        overrides = function()
          return {
            -- Faint seletion.
            FaintSelected = {
              link = "Underlined",
            },
            -- Set cursorline to be empty rather than using :set cursorline.
            -- If wanting to use any cursorline linked to this, need manually setting.
            CursorLine = { bg = "" },
            CursorLineNoneEmpty = { link = "Visual" },
            -- Basics
            SnacksPickerDir = { link = "SnacksPickerFile" },
            -- SnacksPickerDir = { link = "Delimiter" },
            SnacksPickerMatch = { link = "Search" },
            SnacksPickerPreviewCursorLine = { link = "CursorLineNoneEmpty" },
            -- Completion/documentation Pmenu border color when using bordered windows
            Pmenu = { bg = "" },
            PmenuSbar = { bg = "" },
            PmenuSel = { link = "CursorLineNoneEmpty" },
            -- PmenuMatch = { link = "Visual" },
            -- PmenuMatchSel = { link = "Visual" },
            CmpPmenuBorder = { link = "Comment" },
            CompeDocumentationBorder = { link = "Comment" },
            -- System wide borders color.
            StatusLine = { bg = "" },
            StatusLineTerm = { bg = "" },
            WinBar = { bg = "" },
            WinBarNC = { bg = "" },
            -- Telescope borders
            TelescopeBorder = { link = "Constant" },
            WinSeparator = { fg = "#565f89" },
            -- Message region separator
            MsgSeparator = { bg = "" },
            -- Scrollbar
            SatelliteCursor = { fg = "#F8F8F2" },
            -- LSP.
            LspInlayHint = { fg = "#969696" },
            -- Diff
            DiffAdd = { bg = "#1e4839", fg = "#b9e0d3" },
            DiffDelete = { bg = "#4c232d", fg = "#e8b9b8" },
            DiffChange = {},
            DiffText = { link = "DiffAdd" },
            -- Dap
            debugPc = { bg = "#21222C" }
          }
        end,
      })
      vim.cmd([[ colorscheme dracula ]])
    end,
  },
  {
    "folke/noice.nvim",
    enabled = true,
    lazy = false,
    init = function()
      -- add another silent print ( that don't leave history ) as old one.
      vim.print_silent = vim.print
      -- Integrates the older vim.print to new pipeline.
      --  Without this, vim.print() can only be seen from ":messages"
      vim.print = function(...)
        for _, value in ipairs({ ... }) do
          vim.notify("[vim.print] " .. vim.inspect(value), vim.log.levels.INFO)
        end
      end
    end,
    -- replace the keymap
    keys = function()
      return {
        {
          "<leader>im",
          "<Cmd>NoiceHistory<CR>",
          mode = "n",
        },
        -- {
        --   "<leader>iM",
        --   "<Cmd>messages<CR>",
        --   mode = "n",
        -- },
      }
    end,
    config = function()
      --[[require("lualine").setup({
        sections = {
          lualine_x = {
            {
              require("noice").api.statusline.mode.get,
              cond = require("noice").api.statusline.mode.has,
              color = { fg = "#ff9e64" },
            },
          },
        },
      })
      ]]
      --
      require("noice").setup({
        -- Styling
        presets = {
          bottom_search = true,
          command_palette = false,
        },
        cmdline = {
          view = "cmdline",
        },
        views = {
          mini = {
            win_options = {
              winblend = 0,
            },
          },
          cmdline_popup = {
            position = {
              row = 5,
              col = "50%",
            },
            size = {
              width = 60,
              height = "auto",
            },
          },
        },
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "noice",
        callback = function()
          vim.keymap.set("n", "gf", function()
            local f = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
            if f == "" then
              vim.print_silent("no file under cursor")
            else
              -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("q", true, false, true), "t", false)
              vim.cmd("close")
              vim.cmd("e " .. f)
            end
          end, { buffer = true })
        end,
      })
    end,
  },
  -- the opts function can also be used to change the default opts:
  {
    "nvim-lualine/lualine.nvim",
    commit = "86fe395",
    event = "VeryLazy",
    --[[opts = function(_, opts)
      local trouble = require("trouble")
      local symbols = trouble.statusline({
        mode = "lsp_document_symbols",
        groups = {},
        title = false,
        filter = { range = true },
        format = "{kind_icon}{symbol.name:Normal}",
        -- The following line is needed to fix the background color
        -- Set it to the lualine section you want to use
        hl_group = "lualine_c_normal",
      })
      table.insert(opts.sections.lualine_c, {
        symbols.get,
        cond = symbols.has,
      })
    end,]]
    config = function()
      local theme = {
        inactive = {
          a = { fg = nil, bg = nil },
          b = { fg = nil, bg = nil },
          c = { fg = nil, bg = nil },
        },
        visual = {
          a = { fg = nil, bg = nil },
          b = { fg = nil, bg = nil },
          c = { fg = nil, bg = nil },
        },
        replace = {
          a = { fg = nil, bg = nil },
          b = { fg = nil, bg = nil },
          c = { fg = nil, bg = nil },
        },
        normal = {
          a = { fg = nil, bg = nil },
          b = { fg = nil, bg = nil },
          c = { fg = nil, bg = nil },
        },
        insert = {
          a = { fg = nil, bg = nil },
          b = { fg = nil, bg = nil },
          c = { fg = nil, bg = nil },
        },
        command = {
          a = { fg = nil, bg = nil },
          b = { fg = nil, bg = nil },
          c = { fg = nil, bg = nil },
        },
      }
      local overseer = require("overseer")
      local overseer_config_block = {}
      if overseer then
        overseer_config_block = {
          "overseer",
          label = "", -- Prefix for task counts
          colored = true, -- Color the task icons and counts
          symbols = {
            {
              [overseer.STATUS.FAILURE] = "F:",
              [overseer.STATUS.SUCCESS] = "S:",
              [overseer.STATUS.RUNNING] = "R:",
            },
          },
          unique = false, -- Unique-ify non-running task count by name
          name = nil, -- List of task names to search for
          name_not = false, -- When true, invert the name search
          status = { overseer.STATUS.FAILURE, overseer.STATUS.SUCCESS, overseer.STATUS.RUNNING }, -- List of task statuses to display
          status_not = false, -- When true, invert the status search
        }
      end
      local dap_block = {
        function()
          local ret = "DBG "
          if not vim.g.debugging_session_status then
            return ret .. '>'
          end
          local ss = vim.g.debugging_session_status()
          if ss.stopped_session + ss.running_session == 1 then
            -- Display no number when there is only one session.
            if ss.stopped_session == 1 then
              return ret .. " " .. ">"
            else
              return ret .. "󰜎 " .. ">"
            end
            return ret .. '>'
          end
          -- More than one session. Display count.
          if ss.stopped_session > 0 then
            ret = ret .. " ".. ss.stopped_session .. " "
          end
          if ss.running_session > 0 then
            ret = ret .. "󰜎 ".. ss.running_session .. " "
          end
          return ret .. ">"
        end,
        -- icon = { "?", color = { fg = "#e7c664" } }, -- nerd icon.
        cond = function()
          if vim.g.debugging_keymap then
            return true
          end
          local session = require("dap").session()
          if package.loaded.dap and session ~= nil and session ~= {} then
            return true
          end
          return false
        end,
        -- Color
        -- color = { fg = "#e7c664" },
        color = function()
          if vim.g.debugging_keymap then
            return { bg = "#7358D6" }
          end
          return { fg = nil, bg = nil }
        end,
      }
      require("lualine").setup({
        options = {
          theme = theme,
          global_status = true,
          section_separators = "",
          component_separators = "",
        },
        sections = {
          -- lualine_a = { "vim.g.is_debugging or ''" }, -- Used to display is Debugging information.
          -- Replaced with <C-G> mapping to show context.
          --[[lualine_a = {{
            function()
              return require("nvim-navic").get_location()
            end,
            cond = function()
              return package.loaded["nvim-navic"] and require("nvim-navic").is_available()
            end,
          }}, -- Used to display is Debugging information.]]
          lualine_a = {
            { "filename", path = 1 },
          },
          lualine_b = {},
          lualine_c = {},
          lualine_x = {
            dap_block
          },
          lualine_y = {
            overseer_config_block,
          },
          lualine_z = {
            {
              function()
                -- prefix.
                local sys_sign = function()
                  -- Use user defined option first.
                  if vim.g._status_bar_system_icon and #vim.g._status_bar_system_icon > 0 then
                    return vim.g._status_bar_system_icon
                  end
                  local sysname = vim.loop.os_uname().sysname
                  if sysname == "Darwin" then
                    return "󰀵" -- Mac icon
                  elseif sysname == "Linux" then
                    return "" -- Linux icon
                  else
                    return "" -- Default case, no icon
                  end
                end
                local maximized = function()
                  if vim.t.window_maximized then
                    return "m"
                  end
                  return ""
                end
                local recording = function()
                  if vim.g.recording_status == true then
                    return "q"
                  else
                    return ""
                  end
                end
                local debug_keymap = function()
                  if vim.g.debugging_keymap == true then
                    return ""
                  else
                    return ""
                  end
                end
                local status_sign = function()
                  local signs = recording() .. maximized() .. debug_keymap()
                  if #signs > 0 then
                    return "[" .. signs .. "] "
                  end
                  return ""
                end
                local debug_sign = function()
                  if vim.g.debugging_status == "NoDebug" then
                    return ""
                  end
                  if vim.g.debugging_status == "Running" then
                    return ""
                  end
                  if vim.g.debugging_status == "DebugOthers" then
                    return ""
                  end
                  if vim.g.debugging_status == "Stopped" then
                    return ""
                  end
                  return ""
                end
                local cwd = function()
                  local workdir = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
                  local tabname = vim.g.tabname(vim.api.nvim_tabpage_get_number(vim.api.nvim_get_current_tabpage()))
                  if tabname ~= workdir then
                    return workdir .. " => " .. tabname
                  end
                  return tabname
                end
                return status_sign() .. "{" .. cwd() .. "} | " .. sys_sign() .. ""
              end,
            },
          },
        },
      })
    end,
  },
  {
    "petertriho/nvim-scrollbar",
    keys = {
      {
        "<leader>ub",
        function()
          require("scrollbar.utils").toggle()
        end,
        mode = "n",
        desc = "Toggle scrollbar",
      },
    },
    config = function()
      require("scrollbar").setup({
        handle = {
          color = "#2D4263",
          hide_if_all_visible = true,
        },
        marks = {
          Search = {
            text = { "+", "*" },
            priority = 1,
            gui = nil,
            color = "#FFB86C",
            cterm = nil,
            color_nr = nil, -- cterm
            highlight = "Search",
          },
          Visual = {
            text = { "v" },
            priority = 1,
            gui = nil,
            color = "#FFB86C",
            cterm = nil,
            color_nr = nil, -- cterm
            highlight = "Visual",
          },
        },
        excluded_filetypes = {
          "dap-float",
          "AvanteInput",
          "AvanteSelectedFiles",
          "AvantePromptInput",
        },
        handlers = {
          cursor = true,
          diagnostic = true,
          gitsigns = true, -- Requires gitsigns
          handle = true,
          search = true, -- Requires hlslens
          ale = false, -- Requires ALE
        },
      })
      require("gitsigns").setup()
      require("scrollbar.handlers.gitsigns").setup()
      require("scrollbar.handlers").register("lastjump", function(bufnr)
        if vim.api.nvim_get_current_buf() ~= bufnr then
          return { { line = 0, text = "" } } -- dummy-return to prevent error
        end
        if vim.tbl_contains({ "v", "V", "s" }, vim.fn.mode()) then
          local _, vstart, _, _ = unpack(vim.fn.getpos("v"))
          local _, vend, _, _ = unpack(vim.fn.getpos("."))
          if vstart > vend then
            vstart, vend = vend, vstart
          end
          local ret = {}
          for line = vstart, vend, 1 do
            table.insert(ret, {
              line = line,
              type = "Visual",
              level = 1,
            })
          end
          return ret
        end
        return { { line = 0, text = "" } } -- dummy-return to prevent error
      end)
      -- FIXME: only updates when redrawing the bar. and cmd-cr Dunno why..
      --
      -- vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "CursorMoved", "CursorMovedI", "ModeChanged" }, {
      --   pattern = { "*" },
      --   callback = function()
      --     if vim.tbl_contains({ "v", "V", "s" }, vim.fn.mode()) then
      --       vim.print("123")
      --       require("scrollbar").render()
      --     end
      --   end,
      -- })
    end,
  },
  {
    "kevinhwang91/nvim-hlslens",
    dependencies = { "petertriho/nvim-scrollbar" },
    config = function()
      -- require('hlslens').setup() is not required
      require("scrollbar.handlers.search").setup({
        override_lens = function() end,
      })
    end,
  },
  {
    "tadaa/vimade",
    opts = {
      recipe = { "minimalist", { animate = true } },
      ncmode = "buffers",
      fadelevel = 0.66,
      blocklist = {
        default = {
          highlights = {
            "WinSeparator",
            -- sp = {rgb={255,0,0}, intensity=0.5}, -- adds 50% red to special characters
          },
          -- Still problematic. AvanteSidebarWinHorizontalSeparator will be hidden.
          -- buf_opts = { filetype = { "Avante", "AvanteSelectedFiles" } },
          buf_opts = { filetype = { "noice", "qf" } },
        },
      },
    },
  },
}
