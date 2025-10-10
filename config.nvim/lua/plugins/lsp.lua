return {
  {
    "williamboman/mason.nvim",
    cmd = {
      "Mason",
      "MasonInstall",
    },
    -- disable mason keymaps.
    keys = function(_)
      return {}
    end,
    config = function()
      ---@param package_name string
      ---@return boolean
      require("mason").is_installed = function(package_name)
        local mason_registry = require("mason-registry")
        local package = mason_registry.get_package(package_name)
        return package:is_installed()
      end

      ---@param package_name string
      ---@param link_source string
      require("mason").link_as_install = function(package_name, link_source)
        local package_path = require("mason-core.installer.InstallLocation").global():package()
        local bin_path = require("mason-core.installer.InstallLocation").global():bin()

        -- Create package directory
        local package_dir = package_path .. "/" .. package_name
        vim.fn.mkdir(package_dir, "p")

        -- Create symlink from link_source to package_path/package_name/package_name
        local package_binary = package_dir .. "/" .. package_name
        vim.fn.delete(package_binary) -- Remove if exists
        vim.loop.fs_symlink(link_source, package_binary)

        -- Create symlink from package binary to bin_path/package_name
        local bin_binary = bin_path .. "/" .. package_name
        vim.fn.delete(bin_binary) -- Remove if exists
        vim.loop.fs_symlink(package_binary, bin_binary)

        -- Make sure the binary is executable
        vim.fn.setfperm(package_binary, "rwxr-xr-x")
        vim.fn.setfperm(bin_binary, "rwxr-xr-x")
      end

      ---@param package_name string
      ---@param executable_name? string
      --- Try to link from executable before falling back to install from mason.
      require("mason").try_link_before_install = function(package_name, executable_name)
        executable_name = executable_name or package_name
        local path = vim.fn.exepath(executable_name)
        -- no local rust-analyzer, return to mason to install.
        if #path == 0 then
          return package_name
        end
        vim.print(path)
        if not require("mason").is_installed(package_name) then
          require("mason").link_as_install(package_name, path)
        end
      end
      require("mason").ensure_installed = {
        rust = {
          -- install rust-analyzer manually and link to there.
          -- "bacon",
          function()
            require("mason").try_link_before_install("rust-analyzer")
          end,
          "codelldb", -- Also used for Rust
        },
        make = {
          "checkmake",
        },
        cmake = {
          "cmake-language-server",
          -- "cmakelint", -- cmakelang includes cmake-lint.
          "cmakelang",
        },
        cpp = {
          "clang-format",
          "clangd",
          -- "cpplint", -- A little bit too annoying..

          -- "cpptools", -- vscode cppdbg, executable `OpenDebugAD7`. In replacement to codelldb. Known to have certain limitations, use codelldb if possible.
          "codelldb",
        },
        python = {
          -- "black",
          -- "delve",
          "pyright",
          "debugpy", -- Installing it anyway, despite its ususally being installed from venv manager. Mason should be a fallback option.
          "ruff", -- Used as formatter as well linter.
        },
        docker = {
          -- "hadolint",
          -- "docker-compose-language-service",
          -- "dockerfile-language-server",
        },
        golang = {
          "gofumpt",
          "goimports",
          "gomodifytags",
          "gopls",
          "impl", -- TODO: not tried yet...
        },
        json = {
          "jsonlint",
          "fixjson",
        },
        lua = {
          "lua-language-server",
          -- "luacheck",
          "stylua",
          "luaformatter",
        },
        vimscript = {
          "vim-language-server",
        },
        markdown = {
          "markdown-toc",
          -- "markdownlint-cli2",
          "marksman",
        },
        shell = {
          "shfmt",
          "bash-language-server",
          "bash-debug-adapter",
        },
        sql = {
          -- "sql-formatter",
          -- "sqlfluff",
        },
        toml = {
          "taplo",
        },
        tex = {
          -- "texlab",
        },
        yaml = {
          "yaml-language-server",
        },
        xml = {
          "lemminx",
          "xmlformatter",
        },
        nix = {
          "nixpkgs-fmt",
          "nixfmt",
          "nil",
        },
      }

      -- Create MasonInstallAll autocmd.
      -- Setup with ensure_installed.
      require("mason").setup({
        max_concurrent_installers = 10,
        -- Mason should serve as a fallback manager to language-sepcific pkg manager.
        PATH = "prepend",
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter" },
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
            iinclude_surrounding_whitespace = true,
          },
        },
      })
    end,
  },
  {
    -- lsp configurations:
    -- 1. Configure lsp from here as example does: https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
    -- 2. LspInfo to check if working.
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      -- local keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- keys[#keys + 1] = { "K", false }
      -- keys[#keys + 1] = { "<C-K>", false, mode = { "i" } }
      -- markdown config.
      lspconfig.marksman.setup({
        on_attach = lspconfig.marksman.LspOnAttach,
        capabilities = lspconfig.marksman.LspCapabilities,
      })
      -- clang config.
      local cmp_nvim_lsp = require("cmp_nvim_lsp")
      -- lua config
      lspconfig.lua_ls.setup({
        capabilities = cmp_nvim_lsp.default_capabilities(),
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
      -- nix
      lspconfig.nil_ls.setup({})

      if vim.g.modules.cpp and vim.g.modules.cpp.enabled then
        -- cmake
        lspconfig.cmake.setup({})
        lspconfig.clangd.setup({
          -- on_attach = on_attach,
          capabilities = cmp_nvim_lsp.default_capabilities(),
          cmd = {
            "clangd",
            "--offset-encoding=utf-16",
            "--background-index",
            "-j=" .. math.max((vim.g._resource_cpu_cores or 0) - 2, 2),
          },
        })
      end

      if vim.g.modules.go and vim.g.modules.go.enabled then
        -- cmake
        lspconfig.gopls.setup({})
      end
      -- Start LSP inlay hint.
      vim.lsp.inlay_hint.enable(true)
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
        -- cmake = { "cmakelang" },
        cmake = { "cmake-lint" },
        -- for c/cpp linter not recognizing the include path, use envs.
        -- export CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH:$(pwd)/include
        -- export C_INCLUDE_PATH=$C_INCLUDE_PATH:$(pwd)/include
        -- c = { "cpplint" }, -- too annoying...
        -- cpp = { "cpplint" },
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
        -- Refreshing.
        function()
          vim.print_silent("@conform.format")
          -- Run conform formatting.
          if not (vim.g.do_not_format_all and vim.fn.mode() == "n") then
            require("conform").format()
          end
          -- Linter.
          require("lint").try_lint()
          -- Try save
          if not vim.api.nvim_buf_get_name(0) == "" then
            -- Do not save if new buffer.
            vim.cmd([[ :w ]]) -- triggers lsp updating.
          end
          -- Scrollbar
          require("scrollbar").render() -- try to update the scrollbar.
          -- vim.cmd("SatelliteRefresh")
          -- Sometimes nvim-dap-virual-text does not quit after debug session ends.
          vim.cmd[[ DapVirtualTextForceRefresh ]]
        end,
        mode = { "n", "v" }, -- under visual mode, selected range will be formatted.
        desc = "[F]ormat buffer with conform.",
      },
    },
    opts = {
      formatters_by_ft = {
        -- Conform will run multiple formatters sequentially
        -- You can customize some of the format options for the filetype (:help conform.format)
        nix = { "nixfmt", "nixpkgs-fmt" },
        lua = { "stylua" },
        c = { "clang-format" },
        cmake = { "cmake-format" },
        cpp = { "clang-format" },
        python = { "ruff" },
        golang = { "goimports", "gopls" },
        rust = { "rustfmt", lsp_format = "fallback" },
        json = { "fixjson" },
        xml = { "xmlformatter" },
        bash = { "shfmt" },
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
    keys = {
      {
        "<leader>rn",
        ":IncRename ",
        mode = "n",
        desc = "n",
      },
      -- FIXME: Not working now.
      {
        "<leader>rN",
        "<leader>cR", -- rename file.
        mode = "n",
        desc = "n",
      },
    },
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
  {
    "lukas-reineke/indent-blankline.nvim",
    dependencies = {
      "folke/snacks.nvim",
    },
    -- event = "LazyFile",
    opts = function()
      Snacks.toggle({
        name = "Indention Guides",
        get = function()
          return require("ibl.config").get_config(0).enabled
        end,
        set = function(state)
          require("ibl").setup_buffer(0, { enabled = state })
        end,
      }):map("<leader>ug")
      return {
        indent = {
          char = "│",
          tab_char = "│",
        },
        scope = { show_start = false, show_end = false },
        exclude = {
          filetypes = {
            "Trouble",
            "alpha",
            "dashboard",
            "help",
            "lazy",
            "mason",
            "neo-tree",
            "notify",
            "snacks_dashboard",
            "snacks_notif",
            "snacks_terminal",
            "snacks_win",
            "toggleterm",
            "trouble",
          },
        },
      }
    end,
    main = "ibl",
  },
  {
    "folke/lazydev.nvim",
    ft = "lua", -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
}
