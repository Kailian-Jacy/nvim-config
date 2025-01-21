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

  -- change some telescope options and a keymap to browse plugin files
  {
    "nvim-telescope/telescope.nvim",
    keys= {
      {
        "<leader>ff",
        "<cmd>Telescope find_files no_ignore=false<CR>",
        mode = { "n" },
      },
      {
        "<leader>fh",
        "<cmd>Telescope help_tags<CR>",
        mode = { "n" },
      },
      {
        "<leader>fh",
        "\"zy:Telescope help_tags default_text=<C-r>z<CR>",
        mode = { "v" },
      },
      {
        "<leader>fF",
        "<cmd>Telescope find_files no_ignore=true<CR>",
        mode = { "n" },
      },
      {
        "<leader>fo",
        "<cmd>Telescope oldfiles<cr>",
        mode = { "n" },
      }
    },
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
    keys = {
      {
        "<leader>/",
        "<cmd>Telescope live_grep<cr>",
        mode = "n",
      },
      {
        "<leader>/",
        "\"zy:Telescope live_grep default_text=<C-r>z<cr>",
        mode = "v",
      },
    },
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
