return {
  {
    "mfussenegger/nvim-dap",
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
