return {
  {
    -- lsp configurations:
    -- 1. Configure lsp from here as example does: https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
    -- 2. LspInfo to check if working.
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local lspconfig = require("lspconfig")
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      keys[#keys + 1] = { "K", false }
      keys[#keys + 1] = { "<C-K>", false, mode = { "i" } }
      -- markdown config.
      lspconfig.marksman.setup({
        on_attach = lspconfig.marksman.LspOnAttach,
        capabilities = lspconfig.marksman.LspCapabilities,
      })
      -- clang config.
      local cmp_nvim_lsp = require("cmp_nvim_lsp")
      lspconfig.clangd.setup({
        -- on_attach = on_attach,
        capabilities = cmp_nvim_lsp.default_capabilities(),
        cmd = {
          "clangd",
          "--offset-encoding=utf-16",
        },
      })
      -- lua config
      lspconfig.lua_ls.setup({
        settings = {
          Lua = {
            diagnostics = {
              -- let lua interpreter recognize vim as global to disable warnings.
              globals = { "vim" },
            },
          },
        },
      })
      -- json config
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities.textDocument.completion.completionItem.snippetSupport = true
      lspconfig.jsonls.setup({
        capabilities = capabilities,
      })
      -- docker/docker-compose
      lspconfig.docker_compose_language_service.setup({})
      lspconfig.dockerls.setup({})
      -- yaml
      lspconfig.yamlls.setup({})
      -- python
      lspconfig.pyright.setup({})
      -- cmake
      lspconfig.cmake.setup({})
      return opts
    end,
  },
  {
    -- nvim lint:
    -- 1. Add linter here.
    -- 2. Use LintInfo in the filetype.
    -- 3. If linter still not working on save or formatting, trigger with vim.print(require("lint").try_lint())
    "mfussenegger/nvim-lint",
    config = function()
      require("lint").linters_by_ft = {
        json = { "jsonlint" },
        -- rust = { "bacon" }, For rust we just use rust-analysis.
        makefile = { "checkmake" },
        cmake = { "cmakelang" },
        -- for c/cpp linter not recognizing the include path, use envs.
        -- export CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH:$(pwd)/include
        -- export C_INCLUDE_PATH=$C_INCLUDE_PATH:$(pwd)/include
        c = { "cpplint" },
        cpp = { "cpplint" },
        docker = { "hadolint" },
        -- lua = { "luacheck" },
        -- markdown = { "markdownlint-cli2" },
        python = { "ruff" },
        sql = { "sqlfluff" },
        -- go = { "gopls" },
      }
    end,
  },
  {
    "stevearc/conform.nvim",
    keys = {
      {
        "<leader><CR>",
        -- conform formatting
        function()
          require("conform").format()
          require("lint").try_lint()
          vim.print("@conform.format")
        end,
        mode = { "n", "v" }, -- under visual mode, selected range will be formatted.
        desc = "[F]ormat buffer with conform.",
      },
    },
    opts = {
      formatters_by_ft = {
        -- Conform will run multiple formatters sequentially
        -- You can customize some of the format options for the filetype (:help conform.format)
        lua = { "stylua" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        cmake = { "cmake-lint" },
        python = { "ruff" },
        golang = { "goimports", "gopls" },
        rust = { "rustfmt", lsp_format = "fallback" },
        json = { "fixjson" },
        -- Conform will run the first available formatter
      },
      format_on_save = false,
      -- Conform will notify you when a formatter errors
      notify_on_error = true,
      -- Conform will notify you when no formatters are available for the buffer
      notify_no_formatters = true,
    },
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
  },
  {
    "smjonas/inc-rename.nvim",
    config = function()
      require("inc_rename").setup({})
    end,
  },
  {
    "stevearc/aerial.nvim",
    keys = {
      {
        "J",
        "<cmd>AerialNext<CR>",
        mode = { "n" },
        desc = "Move up to last function call.",
      },
      {
        "K",
        "<cmd>AerialPrev<CR>",
        mode = { "n" },
        desc = "Move up to next function call.",
      },
      {
        -- no visual mode for this keymap. just use lsp gd.
        "<leader>ss",
        "<cmd>Telescope aerial<cr>",
        mode = { "n" },
        desc = "Navigate symbols in buffer.",
      },
      {
        "<leader>fs",
        "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
        mode = { "n" },
        desc = "Show all symbols in working directory.",
      },
      {
        "<leader>fs",
        "zy:Telescope lsp_dynamic_workspace_symbols default_text=<C-r>z<cr>",
        mode = { "v" },
        desc = "Show all symbols in working directory.",
      },
    },
    config = function()
      require("aerial").setup({
        backends = { "lsp", "treesitter", "markdown", "asciidoc", "man" },
        -- optionally use on_attach to set keymaps when aerial has attached to a buffer
        require("telescope").setup({
          extensions = {
            aerial = {
              -- Display symbols as <root>.<parent>.<symbol>
              show_nesting = {
                ["_"] = false, -- This key will be the default
                json = true, -- You can set the option for specific filetypes
                yaml = true,
              },
            },
          },
        }),
      })
    end,
  },
}
