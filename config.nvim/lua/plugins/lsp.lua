-- Detect nixCats Nix environment.
-- In Nix, tools (LSPs, formatters, linters) are provided on PATH by Nix;
-- Mason is not needed and should be skipped.
-- In non-Nix environments, Mason manages everything as before.
local is_nix = vim.g.nixCats ~= nil

return {
  {
    "williamboman/mason.nvim",
    -- In Nix environment, disable Mason entirely: tools come from Nix PATH.
    enabled = not is_nix,
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

      -- NOTE: Mason is a "portable package manager" — it manages what it downloads,
      -- not system binaries. Mason does not officially support linking external binaries.
      -- To prefer system-installed tools over Mason-managed ones, set PATH = "append"
      -- in mason.setup() so system PATH takes priority over Mason's bin/.
      -- For per-tool overrides, configure the consumer plugin directly:
      --   - LSP: lspconfig.xxx.setup({ cmd = { "/path/to/binary" } })
      --   - Formatter: conform.formatters.xxx = { command = "/path/to/binary" }
      --   - Linter: require("lint").linters.xxx.cmd = "/path/to/binary"
      -- See: https://github.com/Kailian-Jacy/nvim-config/issues/30

      require("mason").ensure_installed = {
        rust = {
          -- rust-analyzer: managed by rustaceanvim, not installed via Mason.
          -- If system rust-analyzer is not on PATH, uncomment to let Mason install:
          -- "rust-analyzer",
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
          "ruff",    -- Used as formatter as well linter.
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
          "yamllint",
          "prettier",
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
        ts = {
          "typescript-language-server",
        }
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
    branch = "main",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter" },
    },
    config = function()
      -- nvim-treesitter-textobjects setup: the new version (851e865+) exposes
      -- a top-level .setup() function; older versions only work through
      -- nvim-treesitter.configs.  Guard the call so both paths work and a
      -- stale install doesn't crash on startup.
      local ts_textobjects = require("nvim-treesitter-textobjects")
      if type(ts_textobjects.setup) == "function" then
        ts_textobjects.setup({
          select = {
            lookahead = true,
            include_surrounding_whitespace = true,
          },
        })
      else
        -- Fallback for older plugin versions that use the configs module
        local ok, ts_configs = pcall(require, "nvim-treesitter.configs")
        if ok then
          ts_configs.setup({
            textobjects = {
              select = {
                enable = true,
                lookahead = true,
                include_surrounding_whitespace = true,
                keymaps = {
                  ["af"] = "@function.outer",
                  ["if"] = "@function.inner",
                  ["ac"] = "@class.outer",
                  ["ic"] = "@class.inner",
                },
              },
            },
          })
        else
          vim.notify("nvim-treesitter-textobjects: could not configure (version mismatch)", vim.log.levels.WARN)
        end
      end

      -- Textobject keymaps (for new-style direct API)
      local sel_ok, sel_mod = pcall(require, "nvim-treesitter-textobjects.select")
      local select_textobject = sel_ok and sel_mod.select_textobject or nil
      if select_textobject then
        vim.keymap.set({ "x", "o" }, "af", function()
          select_textobject("@function.outer", "textobjects")
        end, { desc = "Select outer function" })
        vim.keymap.set({ "x", "o" }, "if", function()
          select_textobject("@function.inner", "textobjects")
        end, { desc = "Select inner function" })
        vim.keymap.set({ "x", "o" }, "ac", function()
          select_textobject("@class.outer", "textobjects")
        end, { desc = "Select outer class" })
        vim.keymap.set({ "x", "o" }, "ic", function()
          select_textobject("@class.inner", "textobjects")
        end, { desc = "Select inner class" })
      end

      -- Incremental selection (Tab/Shift-Tab) — replaces the removed
      -- nvim-treesitter incremental_selection module.
      -- Uses built-in vim.treesitter API to walk the node tree.
      local _inc_sel_node = nil  -- tracks current node for incremental expansion

      -- Helper: select a treesitter node in linewise visual mode
      local function select_node(node)
        if not node then return end
        local start_row, _, end_row, end_col = node:range()
        if end_col == 0 and end_row > start_row then
          end_row = end_row - 1
        end
        vim.api.nvim_win_set_cursor(0, { start_row + 1, 0 })
        vim.cmd("normal! V")
        vim.api.nvim_win_set_cursor(0, { end_row + 1, 0 })
      end

      -- Init / expand selection (Tab)
      vim.keymap.set("n", "<Tab>", function()
        local node = vim.treesitter.get_node()
        if not node then return end
        _inc_sel_node = node
        select_node(node)
      end, { desc = "Init treesitter incremental selection" })

      vim.keymap.set("x", "<Tab>", function()
        if not _inc_sel_node then return end
        local parent = _inc_sel_node:parent()
        if parent then
          _inc_sel_node = parent
          select_node(parent)
        end
      end, { desc = "Expand treesitter selection to parent node" })

      -- Shrink selection (Shift-Tab)
      vim.keymap.set("x", "<S-Tab>", function()
        if not _inc_sel_node then return end
        -- Find the first named child to shrink to
        local child = _inc_sel_node:named_child(0)
        if child then
          _inc_sel_node = child
          select_node(child)
        end
      end, { desc = "Shrink treesitter selection to child node" })

      -- Reset tracked node when leaving visual mode
      vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = "[vV\x16]*:n",
        callback = function()
          _inc_sel_node = nil
        end,
      })
    end,
  },
  {
    -- nvim-lspconfig: now used as a "bag of configs" providing default LSP
    -- server configurations. The actual LSP management uses Neovim 0.11+
    -- LSP server configurations using nvim-lspconfig.
    --
    -- Server configs live in config.nvim/lsp/*.lua (on runtimepath).
    -- nvim-lspconfig provides additional defaults that are merged automatically.
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      local cmp_nvim_lsp = require("cmp_nvim_lsp")

      -- markdown
      lspconfig.marksman.setup({})
      -- lua
      lspconfig.lua_ls.setup({
        capabilities = cmp_nvim_lsp.default_capabilities(),
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim", "Snacks" },
            },
          },
        },
      })
      -- json
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities.textDocument.completion.completionItem.snippetSupport = true
      lspconfig.jsonls.setup({ capabilities = capabilities })
      -- docker
      lspconfig.docker_compose_language_service.setup({})
      lspconfig.dockerls.setup({})
      -- yaml
      lspconfig.yamlls.setup({
        capabilities = cmp_nvim_lsp.default_capabilities(),
        settings = {
          yaml = {
            schemaStore = {
              enable = true,
              url = "https://www.schemastore.org/api/json/catalog.json",
            },
            format = { enable = true },
            validate = true,
            hover = true,
            completion = true,
          },
        },
      })
      -- python
      lspconfig.pyright.setup({})
      -- nix
      lspconfig.nil_ls.setup({})
      -- ts
      lspconfig.ts_ls.setup({})

      -- Conditional servers
      if vim.g.modules.cpp and vim.g.modules.cpp.enabled then
        lspconfig.cmake.setup({})
        lspconfig.clangd.setup({
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
        lspconfig.gopls.setup({})
      end

      -- Note: rust-analyzer is managed by rustaceanvim, not enabled here.

      -- Start LSP inlay hints
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
        yaml = { "yamllint" },
        sql = { "sqlfluff" },
        -- go = { "gopls" },
      }
    end,
  },
  {
    "stevearc/conform.nvim",
    cmd = {
      "ConformInfo",
    },
    keys = {
      {
        "<leader><CR>",
        -- Refreshing.
        function()
          vim.print_silent("@conform.format")
          vim.cmd [[ ConformFormat ]]
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
          if vim.g.is_plugin_loaded("nvim-dap-virtual-text") then
            vim.cmd[[ DapVirtualTextForceRefresh ]]
          end
        end,
        mode = { "n", "v" }, -- under visual mode, selected range will be formatted.
        desc = "[F]ormat buffer with conform.",
      },
    },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          -- Conform will run multiple formatters sequentially
          -- You can customize some of the format options for the filetype (:help conform.format)
          nix = { "nixfmt", "nixpkgs-fmt" },
          -- lua = { "stylua" }, -- Stylua fails to work for visual selection format.
          c = { "clang-format" },
          cmake = { "cmake-format" },
          cpp = { "clang-format" },
          python = { "black" },
          golang = { "goimports", "gopls" },
          rust = { "rustfmt", lsp_format = "fallback" },
          json = { "fixjson" },
          yaml = { "prettier", lsp_format = "fallback" },
          xml = { "xmlformatter" },
          bash = { "shfmt" },
          -- Conform will run the first available formatter
        },
        format_on_save = false,
        -- Conform will notify you when a formatter errors
        notify_on_error = true,
        -- Conform will notify you when no formatters are available for the buffer
        notify_no_formatters = true,
      })
      local possible_options = { "select_only", "restrict", "all" }
      if vim.g.format_behavior and (
          -- no default set
            not vim.g.format_behavior.default or
            -- or default invalid.
            vim.g.format_behavior.default and not vim.tbl_contains(possible_options, vim.g.format_behavior.default)
          )
      then
        vim.notify("ConformFormat: format_behavior is not valid", vim.log.levels.ERROR)
      end

      vim.api.nvim_create_user_command("ConformFormat", function()
        vim.g.format_behavior = vim.g.format_behavior or { default = "restrict" }

        local filetype = vim.bo.filetype
        local behavior = vim.g.format_behavior.default
        if vim.g.format_behavior[filetype] then
          behavior = vim.g.format_behavior[filetype]
        end

        -- Select only mode.
        if (behavior == "select_only" and vim.fn.mode() == "n") then
          -- Skip format
          return
        end

        local get_select_line_cnt = function ()
          -- Neovim 0.12: use built-in vim.treesitter APIs instead of
          -- removed nvim-treesitter.ts_utils / nvim-treesitter.parsers
          local parser = vim.treesitter.get_parser()
          if parser then
            parser:parse {
              vim.fn.line "w0" - 1, vim.fn.line "w$"
            }
          else
            vim.notify("LSP: No parser available for current buffer", vim.log.levels.WARN)
            return nil, 0
          end

          local node = vim.treesitter.get_node()

          if node == nil then
            return nil, 0
          end

          -- Use full range to handle exclusive end positions correctly
          local start_row, start_col, end_row, end_col = node:range()
          -- Treesitter uses exclusive end: when end_col == 0, the node
          -- actually ends on the previous line (common for block-level nodes)
          if end_col == 0 and end_row > start_row then
            end_row = end_row - 1
          end

          local line_cnt = end_row - start_row + 1
          return node, line_cnt
        end

        -- Restrict mode selection size.
        if (behavior == "restrict" and vim.fn.mode() == "n") then
          local node, line_cnt = get_select_line_cnt()
          if not node or not line_cnt then
            -- No treesitter node found, fall through to format entire buffer
          elseif vim.g.max_silent_format_line_cnt and vim.g.max_silent_format_line_cnt > 0 and line_cnt > vim.g.max_silent_format_line_cnt then
            return
          else
            -- Neovim 0.12: ts_utils.update_selection() was removed;
            -- select the node's line range using linewise visual mode
            local start_row, _, end_row, end_col = node:range()
            -- Adjust for exclusive end position
            if end_col == 0 and end_row > start_row then
              end_row = end_row - 1
            end
            -- Enter linewise visual mode covering the node's range
            vim.api.nvim_win_set_cursor(0, { start_row + 1, 0 })
            vim.cmd("normal! V")
            vim.api.nvim_win_set_cursor(0, { end_row + 1, 0 })
          end
        end
        require("conform").format({ async = true, lsp_format = "fallback" }, function(err)
          if not err then
            local mode = vim.api.nvim_get_mode().mode
            if vim.startswith(string.lower(mode), "v") then
              vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
            end
          end
        end)
      end, {})
    end,
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
        "gj",
        "<cmd>AerialNext<CR>",
        mode = { "n" },
        desc = "Move up to last function call.",
      },
      {
        "gk",
        "<cmd>AerialPrev<CR>",
        mode = { "n" },
        desc = "Move up to next function call.",
      },
    },
    config = function()
      require("aerial").setup({
        backends = { "lsp", "treesitter", "markdown", "asciidoc", "man" },
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
      }):map("<leader>ui")
      return {
        enabled = not vim.g.indent_blankline_hide or false,
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
