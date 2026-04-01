return {
  {
    "mrcjkb/rustaceanvim",
    version = "^6", -- Recommended
    lazy = false, -- This plugin is already lazy
    keys = {
      {
        "<leader>ge",
        "<cmd>RustLsp relatedDiagnostics<CR>",
        mode = "n",
        ft = "rust",
        desc = "Rust: Show related diagnostics"
      },
      {
        "J",
        "<cmd>RustLsp joinLines<CR>",
        mode = "n",
        ft = "rust",
        desc = "Rust: Join lines"
      },
      {
        "gD",
        "<cmd>RustLsp openDocs<cr>",
        mode = "n",
        ft = "rust",
        desc = "Rust: Join lines"
      },
      {
        "gE",
        "<cmd>RustLsp renderDiagnostic<cr>",
        mode = "n",
        ft = "rust",
        desc = "Render diagnostic"
      },
      {
        "gn",
        "<cmd>RustLsp relatedDiagnostics<cr>",
        mode = "n",
        ft = "rust",
        desc = "Rust: Show related diagnostics"
      },
      {
        "gP",
        "<cmd>RustLsp expandMacro<cr>",
        mode = "n",
        ft = "rust",
        desc = "Rust: Expand macro"
      },
    },
    config = function()
      local is_nix = vim.g.nixCats ~= nil

      vim.g.rustaceanvim = function()
        local cfg = require('rustaceanvim.config')
        -- Determine codelldb extension path.
        local extension_path = ""

        if vim.g.codelldb_extension_path and vim.g.codelldb_extension_path ~= "" then
          -- User-provided path takes priority.
          extension_path = vim.g.codelldb_extension_path
        elseif is_nix then
          -- In Nix environment, use the path exposed via environment variable.
          local env_path = vim.env.CODELLDB_EXTENSION_PATH
          if env_path and env_path ~= "" then
            extension_path = env_path .. "/"
          else
            vim.notify("nixCats: CODELLDB_EXTENSION_PATH not set. Debug may not work.", vim.log.levels.WARN)
          end
        elseif pcall(require, "mason-registry") and require("mason-registry").is_installed("codelldb") then
          extension_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/"
        else
          vim.notify("codelldb not found. Install via Mason or set vim.g.codelldb_extension_path", vim.log.levels.WARN)
        end

        local codelldb_path = extension_path .. 'adapter/codelldb'
        local liblldb_path = extension_path .. 'lldb/lib/liblldb'
        local this_os = vim.uv.os_uname().sysname;

        -- The path is different on Windows
        if this_os:find "Windows" then
          codelldb_path = extension_path .. "adapter\\codelldb.exe"
          liblldb_path = extension_path .. "lldb\\bin\\liblldb.dll"
        else
          -- The liblldb extension is .so for Linux and .dylib for MacOS
          liblldb_path = liblldb_path .. (this_os == "Linux" and ".so" or ".dylib")
        end

        return {
          server = {
            setting = {
              ["rust-analyzer"] = {
                procMacro = { enabled = true },
              },
            },
          },
          dap = {
            adapter = cfg.get_codelldb_adapter(codelldb_path, liblldb_path),
          },
        }
      end
      -- vim.g.rustaceanvim.server.settings["rust-analyzer"].diagnostics = {
      --   enable = true,
      --   disabled = { "unresolved-proc-macro", "unresolved-macro-call" },
      --   enableExperimental = true,
      -- }
    end,
  },
  {
    "saecki/crates.nvim",
    tag = "stable",
    event = { "BufRead Cargo.toml" },
    config = function()
      require("crates").setup({})
    end,
  },
}
