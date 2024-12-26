-- since this is just an example spec, don't actually load anything here and return an empty spec
-- stylua: ignore
-- if true then return {} end

-- every spec file under the "plugins" directory will be loaded automatically by lazy.nvim
--
-- In your plugin files, you can:
-- * add extra plugins
-- * disable/enabled LazyVim plugins
-- * override the configuration of LazyVim plugins
return {
  -- Disable some of the builtin plugins.
  {
    "LazyVim/LazyVim",
    version = "12.44.1",
    opts = {
      colorscheme = "dracula",
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "HiPhish/rainbow-delimiters.nvim" },
    opts = function(_, opts)
      opts.rainbow = {
        enable = true,
        query = "rainbow-delimiters",
        strategy = require("rainbow-delimiters").strategy.global,
      }
      opts.ensure_installed = {
        "bash",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "tsx",
        "rust",
        "go",
        "vim",
        "yaml",
        "json",
        "json5",
      }
      opts.indent = {
        disable = true,
      }
    end,
  },
  {
    "folke/snacks.nvim",
    opts = {
      notify = { enabled = false },
      notifier = {
        enabled = false,
        timeout = 3000,
      },
      words = { enabled = true },
    },
    -- No need for now. Now use nvim build in * to navigate.
    -- keys = {
    --   { "]]", function() require("snacks").words.jump(vim.v.count1) end, desc = "Next Reference" },
    --   { "[[", function() require("snacks").words.jump(-vim.v.count1) end, desc = "Prev Reference" },
    -- },
  },

  -- Trouble:	diagnostic plugin.
  {
    "folke/trouble.nvim",
    -- opts will be merged with the parent spec
    opts = { use_diagnostic_signs = true },
  },

  -- override nvim-cmp
  {
    "hrsh7th/nvim-cmp",
    config = function()
      --[[local has_words_before = function()
        unpack = unpack or table.unpack
        local line, col = unpack(vim.api.nv(0))
        return col ~= 0 and
          vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match('%s') == nil
      end]]
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("cmp").setup({
        auto_brackets = {}, -- disabled. Being managed by other plugins.
        completion = {
          completeopt = "menu,menuone,noinsert,noselect",
        },
        window = {
          completion = {
            border = 'rounded',
            winhighlight = 'Normal:Pmenu,FloatBorder:CompeDocumentationBorder',
            winblend=0,
          },
          documentation = {
            border = 'rounded',
            winhighlight = 'Normal:Pmenu,FloatBorder:CompeDocumentationBorder',
            winblend=0,
          }
        },
        -- Docs has example about how to set for copilot compatibility:
        mapping = cmp.mapping.preset.insert {
          -- Tab will only be used to expand when item being selected. Else you can be sure to tab expand snippets.
          ['<Tab>'] = function(_)
            if cmp.visible() and cmp.get_selected_entry() then
              cmp.confirm({select = false, behavior = cmp.ConfirmBehavior.Replace})
            elseif luasnip.expandable() then 
                luasnip.expand()
            elseif luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              vim.api.nvim_feedkeys(vim.fn['copilot#Accept'](vim.api.nvim_replace_termcodes('<Tab>', true, true, true)), 'n', true)
            end
          end,
          ['<S-Tab>'] = cmp.mapping(function(fallback) 
                if luasnip.locally_jumpable(-1) then
                    luasnip.jump(-1)
                else
                    fallback()
                end
            end),
          -- aligned with nvim screen shift and telescope previews shift. TODO: Not warking now.
          ['<C-u>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
          ['<C-d>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
          -- cancel suggestion.
          ['<C-c>'] = function(_)
            if cmp.visible() and cmp.get_selected_entry() then
              cmp.abort()
            else
              vim.api.nvim_feedkeys(vim.fn['copilot#Clear'](), 'n', true)
            end
          end,
          ['<CR>'] = function(fallback)
            if cmp.visible() and cmp.get_selected_entry() then
              cmp.confirm()
            else
              -- allow <CR> passthrough as normal line switching.
              fallback()
            end
          end,
          -- it's very rare to require copilot to give multiple solutions. If it's not good enough, we'll use avante to generate ai response manually.
          ['<Down>'] = function(_)
            if cmp.visible() then 
              cmp.select_next_item()
            else
              vim.api.nvim_feedkeys(vim.fn['copilot#Next'](), 'n', true)
            end
          end,
          ['<Right>'] = function(_)
            if luasnip.locally_jumpable() then 
              luasnip.jump(1)
            else
              vim.api.nvim_feedkeys(vim.fn['copilot#AcceptLine'](vim.api.nvim_replace_termcodes('<Right>', true, true, true)), 'n', true)
            end
          end,
          ['<Left>'] = cmp.mapping(function(fallback)
            if luasnip.locally_jumpable() then 
              luasnip.jump(-1)
            else
              fallback()
            end
          end),
          ['<Up>'] = function(_)
            if cmp.visible() then 
              cmp.select_prev_item()
            else
              vim.api.nvim_feedkeys(vim.fn['copilot#Previous'](), 'n', true)
            end
          end,
          ['<C-j>'] = function(_)
            if cmp.visible() then 
              cmp.select_next_item()
            else
              vim.api.nvim_feedkeys(vim.fn['copilot#Next'](), 'n', true)
            end
          end,
          ['<C-k>'] = function(_)
            if cmp.visible() then 
              cmp.select_prev_item()
            else
              vim.api.nvim_feedkeys(vim.fn['copilot#Previous'](), 'n', true)
            end
          end
        },
        experimental = {
          ghost_text = false -- this feature conflict with copilot.vim's preview.
        },
        sources = {
          { name = 'luasnip' },
          {
            name = "cmp_tabnine",
            group_index = 1,
          },
          {
            name = 'nvim_lsp',
          },
          { name = 'buffer' },
          { name = "nvim_lua" }, { name = "path" },
        },
        sorting = {
          priority_weight = 100,
          comparators = {
            cmp.config.compare.offset,
            cmp.config.compare.exact,
            cmp.config.compare.score,
            cmp.config.compare.recently_used,
            require("cmp-under-comparator").under,
            cmp.config.compare.kind,
          },
        },
        matching = {
          disallow_fuzzy_matching = false,
          disallow_fullfuzzy_matching = false,
          disallow_partial_fuzzy_matching = false,
          disallow_partial_matching = false,
          disallow_prefix_unmatching = false,
          disallow_symbol_nonprefix_matching = false
        }
      });
      cmp.setup.cmdline({ '/', '?' }, {
        -- mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = 'buffer' }
        }
      });
      -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
      cmp.setup.cmdline(':', {
        -- mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = 'path' }
        }, {
          { name = 'cmdline' }
        }),
      });
    end,
  },

  -- change some telescope options and a keymap to browse plugin files
  {
    "nvim-telescope/telescope.nvim",
    -- keys = {
    -- add a keymap to browse plugin files
    -- stylua: ignore
    -- {
    --	 "<leader>fp",
    --	 function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
    --	 desc = "Find Plugin File",
    -- },
    -- },
    dependencies = {
      {
        "nvim-telescope/telescope-live-grep-args.nvim",
        -- This will not install any breaking changes.
        -- For major updates, this must be adjusted manually.
        version = "^1.0.0",
      },
      {
        "nvim-telescope/telescope-fzf-native.nvim",
      }
    },
    -- change some options
    opts = {
      defaults = {
        wrap_results = true,
        layout_strategy = "vertical",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
        file_ignore_patterns = {
          "%.o",
          "%.obj",
          "%.a",
          "%.lib",
          "%.dll",
          "%.exe",
          "%.pdb",
          "%.sln",
          "%.vcxproj",
          "Session.vim",
        },
        mappings = {
          i = { ["<c-t>"] = require("trouble.sources.telescope").open},
          n = { ["<c-t>"] = require("trouble.sources.telescope").open },
        }
      }
    },
  },
  {
    "nvim-telescope/telescope-live-grep-args.nvim",
    version = "^1.0.0",
    config = function ()
      local t = require("telescope")
      local lga_actions = require("telescope-live-grep-args.actions")
      t.setup({
        extensions = {
          live_grep_args = {
            auto_quoting = true, -- enable/disable auto-quoting
            -- define mappings, e.g.
            mappings = { -- extend mappings
              i = {
                ["<C-k>"] = lga_actions.quote_prompt(),
                ["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
                -- freeze the current list and start a fuzzy search in the frozen list
                --["<C-space>"] = actions.to_fuzzy_refine,
              },
            },
            -- ... also accepts theme settings, for example:
            -- theme = "dropdown", -- use dropdown theme
            -- theme = { }, -- use own theme spec
            -- layout_config = { mirror=true }, -- mirror preview pane
          }
        }
      })
      t.load_extension("live_grep_args")
    end
  },
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release',
    config = function ()
      -- To get fzf loaded and working with telescope, you need to call
      -- load_extension, somewhere after setup function:
      require('telescope').load_extension('fzf')
    end
  },
  --[[{
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    config = function()
      require('dashboard').setup {
        theme = 'hyper',
        config = {
          week_header = {
            enable = true,
          },
          project = { enable = true, limit = 8, icon = 'your icon', label = '', action = 'Telescope find_files cwd=' },
          mru = { limit = 10, icon = 'your icon', label = '', cwd_only = false },
          shortcut = {
            { desc = '󰊳 Update', group = '@property', action = 'Lazy update', key = 'u' },
            {
              icon = ' ',
              icon_hl = '@variable',
              desc = 'Files',
              group = 'Label',
              action = 'Telescope find_files',
              key = 'f',
            },
            {
              desc = ' Apps',
              group = 'DiagnosticHint',
              action = 'Telescope app',
              key = 'a',
            },
            {
              desc = ' dotfiles',
              group = 'Number',
              action = 'Telescope dotfiles',
              key = 'd',
            },
          },
        },
      }
    end,
    dependencies = { { 'nvim-tree/nvim-web-devicons' } }
  },]]
  {
    "okuuva/auto-save.nvim",
    event = { "InsertLeave", "TextChanged" },
    config = function()
      require("auto-save").setup({
        trigger_events = {
            defer_save = { 
                        "InsertLeave", 
                        "TextChanged", 
                        {"TextChangedP", pattern = "*.md"}, 
                        {"TextChangedI", pattern = "*.md"}
            },
        },
        -- debounce_delay = 500,
      })
    end,
  },
  {
    "kawre/leetcode.nvim",
    cmd = "Leet",

    build = ":TSUpdate html",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim", -- required by telescope
      "MunifTanjim/nui.nvim",

      -- optional
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      lang = "python3",
      cn = {
        enabled = true,
        translator = true,
        translate_problems = true,
      },
      plugins = {
        non_standalone = true,
      }
    },
  },
  {
    'LukasPietzschmann/telescope-tabs',
    config = function()
      require('telescope').load_extension 'telescope-tabs'
      require('telescope-tabs').setup {
        -- Your custom config :^)
      }
    end,
    dependencies = { 'nvim-telescope/telescope.nvim' },
  },
  {
    "cohama/lexima.vim"
  },
  {
    "gbprod/yanky.nvim",
    config = function() 
        require("yanky").setup({})
        require("telescope").load_extension("yank_history")
    end,
    keys = {
      { "<leader>fp", function() require("telescope").extensions.yank_history.yank_history() end, desc = "Yanky History"}
    }
  },
}
