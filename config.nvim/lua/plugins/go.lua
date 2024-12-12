return {
  --[[{
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "go", "gomod", "gowork", "gosum" },
    },
  },
  --{
  --"neovim/nvim-lspconfig",
  --opts = {
  --servers = {
  --gopls = {
  --settings = {
  --gopls = {
  --gofumpt = true,
  --codelenses = {
  --gc_details = false,
  --generate = true,
  --regenerate_cgo = true,
  --run_govulncheck = true,
  --test = true,
  --tidy = true,
  --upgrade_dependency = true,
  --vendor = true,
  --},
  --hints = {
  --assignVariableTypes = true,
  --compositeLiteralFields = true,
  --compositeLiteralTypes = true,
  --constantValues = true,
  --functionTypeParameters = true,
  --parameterNames = true,
  --rangeVariableTypes = true,
  --},
  --analyses = {
  --fieldalignment = true,
  --nilness = true,
  --unusedparams = true,
  --unusedwrite = true,
  --useany = true,
  --},
  --usePlaceholders = true,
  --completeUnimported = true,
  --staticcheck = true,
  --directoryFilters = { "-.git", "-.vscode", "-.idea", "-.vscode-test", "-node_modules" },
  --semanticTokens = true,
  --},
  --},
  --},
  --},
  --setup = {
  --gopls = function(_, opts)
  ---- workaround for gopls not supporting semanticTokensProvider
  ---- https://github.com/golang/go/issues/54531#issuecomment-1464982242
  --LazyVim.lsp.on_attach(function(client, _)
  --if not client.server_capabilities.semanticTokensProvider then
  --local semantic = client.config.capabilities.textDocument.semanticTokens
  --client.server_capabilities.semanticTokensProvider = {
  --full = true,
  --legend = {
  --tokenTypes = semantic.tokenTypes,
  --tokenModifiers = semantic.tokenModifiers,
  --},
  --range = true,
  --}
  --end
  --end, "gopls")
  ---- end workaround
  --end,
  --},
  --},
  --},
  {
    "williamboman/mason.nvim",
    opts = { ensure_installed = { "goimports", "gofumpt" } },
  },
  {
    "williamboman/mason.nvim",
    opts = { ensure_installed = { "gomodifytags", "impl" } },
  },
  {
    "mfussenegger/nvim-lint",
    event = {
      "BufReadPre",
      "BufNewFile",
    },
    config = function()
      local lint = require("lint")
      lint.lint_by_ft = {
        golang = { "Golangci-lint" },
      }
      local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = lint_augroup,
        callback = function()
          lint.try_lint()
        end,
      })

      vim.keymap.set("n", "<leader>ll", function()
        lint.try_lint()
      end, { desc = "trigger lint for current file" })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local lspconfig = require("lspconfig")
      local configs = require("lspconfig/configs")

      if not configs.golangcilsp then
        configs.golangcilsp = {
          default_config = {
            cmd = { "golangci-lint-langserver" },
            root_dir = lspconfig.util.root_pattern(".git", "go.mod"),
            init_options = {
              command = {
                "golangci-lint",
                "run",
                "--enable-all",
                "--disable",
                "lll",
                "--out-format",
                "json",
                "--issues-exit-code=1",
              },
            },
          },
        }
      end
      lspconfig.golangci_lint_ls.setup({
        filetypes = { "go", "gomod" },
      })
      return opts
    end,
  },]]
  {
    "neovim/nvim-lspconfig",
    config = function()
      local cmp_nvim_lsp = require("cmp_nvim_lsp")
      require("lspconfig").clangd.setup({
        -- on_attach = on_attach,
        capabilities = cmp_nvim_lsp.default_capabilities(),
        cmd = {
          "clangd",
          "--offset-encoding=utf-16",
        },
      })
    end,
  },
  {
    "ray-x/go.nvim",
    dependencies = { -- optional packages
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("go").setup({
        dap_debug_gui = false,
      })
    end,
    event = { "CmdlineEnter" },
    ft = { "go", "gomod" },
    build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
  },
}
