return {
  {
    "mrcjkb/rustaceanvim",
    version = "^6", -- Recommended
    lazy = false, -- This plugin is already lazy
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "rust" },
        callback = function ()
          vim.api.nvim_buf_set_keymap(0, "n", "gD", "<cmd>RustLsp openDocs<cr>", { noremap = true, silent = false })
        end
      })
      vim.g.rustaceanvim = function()
        local cfg = require('rustaceanvim.config')
        -- Check if installed by mason.
        local extension_path = ""
        if vim.g.codelldb_extension_path and vim.g.codelldb_extension_path ~= "" then
          extension_path = vim.g.codelldb_extension_path
        elseif require("mason-registry").is_installed("codelldb") then
          extension_path = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension"
        else
          vim.notify("codelldb not installed by Mason. Please point by vim.g.codelldb_extension_path")
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
