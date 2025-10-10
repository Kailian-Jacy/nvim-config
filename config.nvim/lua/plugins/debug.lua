return {
  {
    "igorlfs/nvim-dap-view",
    cmd = {
      "DapViewToggle",
      "DapViewOpen",
      "DapViewShow",
      "DapViewWatch",
    },
    keys = {
      {
        "<leader>ud",
        "<cmd>DapViewToggle<CR>",
        mode = "n",
        desc = "Toggle DAP View, default to console.",
      },
    },
    config = function ()
      vim.api.nvim_create_autocmd({ "FileType" }, {
        pattern = { "dap-view", "dap-view-term", "dap-repl" }, -- dap-repl is set by `nvim-dap`
        callback = function(args)
            vim.keymap.set("n", "q", "<C-w>q", { buffer = args.buf })
        end,
      })
      require("dap-view").setup({
        winbar = {
          show = true, -- For now.
          sections = { "repl", "console", "watches", "scopes", "exceptions", "breakpoints", "threads", "sessions" },
          base_sections = {
            scopes = {
              keymap = "P",
              label = "Scopes [P]",
              short_label = " [P]",
              action = function()
                require("dap-view.views").switch_to_view("scopes")
              end,
            },
            threads = {
                keymap = "F",
                label = "Frames [F]",
                short_label = "󰂥 [F]",
                action = function()
                    require("dap-view.views").switch_to_view("threads")
                end,
            },
            sessions = {
                keymap = "S", -- I ran out of mnemonics
                label = "Sessions [S]",
                short_label = " [S]",
                action = function()
                    require("dap-view.views").switch_to_view("sessions")
                end,
            },
          },
          default_section = "console"
        }
      })
    end
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    ksys = {
      {
        "<leader>uv",
        "<cmd>DapVirtualTextToggle<cr>",
        desc = "Toggle DAP Virtual Text",
      },
    },
    config = function()
      require("nvim-dap-virtual-text").setup({
        all_references = true,
      })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "jbyuki/one-small-step-for-vimkind",
    },
    lazy = false,
    keys = {
      -- { "<leader>d", "", desc = "+debug", mode = {"n", "v"} },
      -- break points.
      {
        "<leader>xb",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },
      {
        "<leader>xB",
        function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end,
        desc = "Breakpoint Condition",
      },
      -- running control
      --[[{ "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>dp", function() require("dap").pause() end, desc = "Pause" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Step Out" },
      { "<leader>dO", function() require("dap").step_over() end, desc = "Step Over" },]]
      -- { "<leader>dg", function() require("dap").goto_() end, desc = "Go to Line (No Execute)" },
      --[[{ "<leader>dj", function() require("dap").down() end, desc = "Down" },
      { "<leader>dk", function() require("dap").up() end, desc = "Up" },]]
      -- starting.
      {
        "<leader>Dl",
        function()
          require("dap").run_last()
        end,
        desc = "Run Last",
      },
      -- { "<leader>Da", function() require("dap").continue({ before = get_args }) end, desc = "Run with Args" },
      -- To be moved to telescope in the future.
      {
        "<leader>dr",
        function()
          require("dap").repl.toggle()
        end,
        desc = "Toggle REPL",
      },
      {
        "<leader>ds",
        function()
          require("dap").session()
        end,
        desc = "Session",
      },
      -- { "<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
    },
    config = function()
      local dap = require("dap")
      -- Setting up rust debugger using codelldb.
      -- As rustecean-vim said, use codelldb instead of raw lldb.
      -- codelldb is a vscode plugin that enables type: "lldb" in launch.json
      -- Failed to setup rust debugging configuration finally. Use :RustLsp debuggables to debug normal cargo project.
      --    As post *https://github.com/mfussenegger/nvim-dap/discussions/671* said, no such thing as nvim-dap-rust,
      --    It's maintained by rusteceanvim, but his doc seems to be outdated and causing error.
      --    So problem about rust vscode compatibility seems unsolved.

      -- setup keymap before debug session begins.
      dap.listeners.before["event_initialized"]["nvim-dap-noui"] = function(_, _)
        vim.print_silent("Debug Session intialized ")
        vim.g.debugging_status = "DebugOthers"
        require("lualine").refresh()
        -- NoUIKeyMap()
      end
      -- dap.listeners.after.attach["nvim-dap-noui"] = function (_, _)
      --   vim.print_silent("Debug Session Attached to process.")
      -- end
      -- dap.listeners.after.launch["nvim-dap-noui"] = function (_, _)
      --   vim.print_silent("Debug Session Launched.")
      -- end

      -- Customized helper functions.

      ---@return table<string, integer>
      vim.g.debugging_session_status = function ()
        local sessions = dap.sessions()
        local stopped_session = 0
        local running_session = 0
        for _, session in pairs(sessions) do
          if session.stopped_thread_id ~= nil then
            stopped_session = stopped_session + 1
          else
            running_session = running_session + 1
          end
        end
        return {stopped_session = stopped_session, running_session = running_session}
      end

      -- Starting.
      dap.listeners.before["event_stopped"]["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "Running"
        require("lualine").refresh()
      end
      dap.listeners.before["event_continued"]["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "Stopped"
        require("lualine").refresh()
      end

      -- Ending.
      dap.listeners.before.event_terminated["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "NoDebug"
        vim.print_silent("Debug Session Terminated.")
        require("lualine").refresh()
        -- NoUIUnmap()
      end
      dap.listeners.before.event_exited["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "NoDebug"
        vim.print_silent("Debug Session Exited.")
        require("lualine").refresh()
        -- NoUIUnmap()
      end
      dap.listeners.before.disconnect["nvim-dap-noui"] = function(_, _)
        vim.g.debugging_status = "NoDebug"
        vim.print_silent("Debug Session Disconnected.")
        require("lualine").refresh()
        -- NoUIUnmap()
      end

      -- dap.listeners.on_session["nvim-dap-noui"] = function(old_session, new_session)
      --   -- Error code. new session is nil does not mean ending.
      --   if new_session == nil then
      --     -- Session change on last session ends..
      --     vim.g.debugging_status = "NoDebug"
      --     vim.print_silent("Debug Session ends.")
      --     require("lualine").refresh()
      --   elseif old_session  == nil then
      --     -- Session change on last session ends..
      --     vim.g.debugging_status = "DebugOthers"
      --     vim.print_silent("Debug Session Started.")
      --     require("lualine").refresh()
      --   else
      --     -- Switching session.
      --     vim.g.debugging_status = "DebugOthers"
      --     vim.print_silent("Debug Session Switched.")
      --     require("lualine").refresh()
      --   end
      --   -- NoUIUnmap()
      -- end
      -- dap.listeners.before['event_terminated']['nvim-dap-noui'] = dap.listeners.before['event_stopped']['nvim-dap-noui']
      -- Setup windows location and side when debugging with terminal:

      local function get_full_path_of(debugger_exe_name)
        local exe_path = vim.fn.trim(vim.fn.system("which " .. debugger_exe_name))

        -- Check if codelldb is found
        if exe_path == "" then
          -- If not found, show a notification and panic
          vim.notify(
            debugger_exe_name .. " is not installed. Please install it to use the debugger.",
            vim.log.levels.ERROR
          )
        else
          -- Return the absolute path of codelldb
          -- vim.notify(debugger_exe_name .. " loaded.")
          return exe_path
        end
      end

      ---@param name string
      ---@param exe_name? string
      local function dap_register_if_executable(name, exe_name)
        exe_name = exe_name or name
        if vim.fn.executable(exe_name) then
          dap.adapters[name] = {
            id = name,
            type = "executable",
            command = get_full_path_of(exe_name),
          }
        end
      end
      dap_register_if_executable("cppdbg", "OpenDebugAD7")
      dap_register_if_executable("codelldb")
      dap_register_if_executable("gopls")
      -- TODO: Not tried yet..
      dap_register_if_executable("sh", "bash-debug-adapter")

      -- As debugpy is sometimes provided by venv, when switching venv, availability of debugpy may change.
      -- So we just register it here, if debugpy does not exists, we'll let dap reports executable missing.
      dap.adapters.debugpy = {
        type = "executable",
        -- We want to update the actual debugpy instance it points to
        --   as used python executable is updated.
        -- So we are not using full path here.
        command = "debugpy",
        -- env = {},
        name = "debugpy",
      }
      dap.adapters.neovimlua = function(callback, config)
        callback({ type = 'server', host = config.host or "127.0.0.1", port = config.port or 8086 })
      end

      -- Lua debug neovim itself configuration
      dap.configurations.lua = {
        {
          type = 'neovimlua',
          request = 'attach',
          name = "Attach to running Neovim instance",
        }
      }
    end,
  },
  --[[{
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"
    }
  },]]
  -- {
  --   -- "nvim-telescope/telescope-dap.nvim",
  --   "Kailian-Jacy/telescope-dap.nvim",
  --   config = function()
  --     require("telescope").load_extension("dap")
  --   end,
  -- },
}
