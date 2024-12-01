return {
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- rust
        --[["bacon",]]
        -- install rust-analyzer manually and link to there.
        -- cpp
        "checkmake",
        "clang-format",
        "clangd",
        "cmakelint",
        "codelldb",
        "cpplint",
        "cpptools",
        -- python
        --[["debugpy",
        "black",
        "delve",
        "pyright",
        "ruff",]]
        -- docker
        --[["hadolint",
        "docker-compose-language-service docker_compose_language_service",
        "dockerfile-language-server dockerls",]]
        -- golang
        "gofumpt",
        "goimports",
        "gomodifytags",
        "gopls",
        "impl",
        -- json
        --[["jsonlint",]]
        -- lua
        "lua-language-server",
        "luacheck",
        "stylua",
        "luaformatter",
        -- markdown
        "markdown-toc",
        "markdownlint-cli2",
        "marksman",
        -- shell
        "shfmt",
        -- sql
        --[["sql-formatter",
        "sqlfluff",]]
        -- toml
        "taplo",
        -- tex
        --[["texlab",]]
        -- yaml
        "yaml-language-server",
      },
    },
  },
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
        vim.print("Debug Session intialized ")
        vim.g.is_debugging = true
        NoUIKeyMap()
      end
      -- unmap keymap after that.
      dap.listeners.before["event_terminated"]["nvim-dap-noui"] = function(_, _)
        vim.g.is_debugging = false
        vim.print("Debug Session terminated.")
        NoUIUnmap()
      end
      -- dap.listeners.before['event_terminated']['nvim-dap-noui'] = dap.listeners.before['event_stopped']['nvim-dap-noui']
      -- Setup windows location and side when debugging with terminal:

      -- Setting up python debugger.
      local pythonPath = function()
        return require("venv-selector").python()
      end
      require("dap-python").setup(pythonPath())
      table.insert(dap.configurations.python, {
        type = "debugpy",
        request = "launch",
        name = "Python Debug Current File",
        program = "${file}",
        stopOnEntry = true,
        console = "integratedTerminal",
      })
    end,
  },
  --[[{
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"
    }
  },]]
  {
    -- "nvim-telescope/telescope-dap.nvim",
    "Kailian-Jacy/telescope-dap.nvim",
    config = function()
      require("telescope").load_extension("dap")
    end,
  },
}
