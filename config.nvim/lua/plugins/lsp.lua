return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {},
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local lspconfig = require("lspconfig")
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      keys[#keys + 1] = { "K", false }
      lspconfig.marksman.setup({
        on_attach = lspconfig.marksman.LspOnAttach,
        capabilities = lspconfig.marksman.LspCapabilities,
      })
      return opts
    end,
  },
  {
    "mfussenegger/nvim-lint",
    config = function()
      require("lint").linters_by_ft = {
        markdown = { "vale" },
      }
    end,
  },
  {
    "stevearc/conform.nvim",
    formatters_by_ft = {
      -- Conform will run multiple formatters sequentially
      -- You can customize some of the format options for the filetype (:help conform.format)
      lua = { "luaformatter" },
      python = { "ruff" },
      golang = { "goimports", "gopls" },
      rust = { "rustfmt", lsp_format = "fallback" },
      -- Conform will run the first available formatter
    },
    format_on_save = false,
    -- Conform will notify you when a formatter errors
    notify_on_error = true,
    -- Conform will notify you when no formatters are available for the buffer
    notify_no_formatters = true,
  },
  {
    "utilyre/barbecue.nvim",
    name = "barbecue",
    version = "*",
    dependencies = {
      "SmiteshP/nvim-navic",
      "nvim-tree/nvim-web-devicons", -- optional dependency
    },
    opts = {
      -- configurations go here
    },
  }
  -- add tsserver and setup with typescript.nvim instead of lspconfig
  --{
  --"neovim/nvim-lspconfig",
  --dependencies = {
  --"jose-elias-alvarez/typescript.nvim",
  --init = function()
  --require("lazyvim.util").lsp.on_attach(function(_, buffer)
  ---- stylua: ignore
  --vim.keymap.set( "n", "<leader>co", "TypescriptOrganizeImports", { buffer = buffer, desc = "Organize Imports" })
  --vim.keymap.set("n", "<leader>cR", "TypescriptRenameFile", { desc = "Rename File", buffer = buffer })
  ---- vim.keymap.set("n", "K", "TypescriptRenameFile", { desc = "Rename File", buffer = buffer })
  --end)
  --end,
  --},
  -----@class PluginLspOpts
  --opts = {
  -----@type lspconfig.options
  --servers = {
  ---- tsserver will be automatically installed with mason and loaded with lspconfig
  --tsserver = {},
  --},
  ---- you can do any additional lsp server setup here
  ---- return true if you don't want this server to be setup with lspconfig
  -----@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
  --setup = {
  ---- example to setup with typescript.nvim
  --tsserver = function(_, opts)
  --require("typescript").setup({ server = opts })
  --return true
  --end,
  ---- Specify * to use this function as a fallback for any server
  ---- ["*"] = function(server, opts) end,
  --},
  --},
  --},
}
