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
        "folke/snacks.nvim",
        enabled = false,
        opts = {
            notify = { enabled = false },
            notifier = {
                enabled = false,
                timeout = 3000,
            },
            words = { enabled = true },
        },
        keys = {
            { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Next Reference" },
            { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference" },
        },
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
            local has_words_before = function()
                unpack = unpack or table.unpack
                local line, col = unpack(vim.api.nv(0))
                return col ~= 0 and
                    vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match('%s') == nil
            end
            local cmp = require("cmp")
            require("cmp").setup({
                auto_brackets = {}, -- configure any filetype to auto add brackets
                completion = {
                    completeopt = "menu,menuone,noinsert" .. (true and "" or ",noselect"),
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
                mapping = cmp.mapping.preset.insert {
                    ['<CR>'] = cmp.mapping.confirm({
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true,
                    }),
                    ['jj'] = cmp.mapping.confirm({
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true,
                    }),
                    ["<S-Tab>"] = cmp.mapping.select_prev_item(),
                    ["<Tab>"] = cmp.mapping.select_next_item(),
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    -- ['<esc>'] = cmp.mapping.abort()
                },
                sources = {
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
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = 'buffer' }
                }
            });
            -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
            cmp.setup.cmdline(':', {
                mapping = cmp.mapping.preset.cmdline(),
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
                    i = { ["<c-t>"] = require("trouble.sources.telescope").open },
                    n = { ["<c-t>"] = require("trouble.sources.telescope").open },
                }
            }
        },
    },


    -- add more treesitter parsers
    {
        "nvim-treesitter/nvim-treesitter",
        opts = {
            ensure_installed = {
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
            },
        },
    },

    -- add any tools you want to have installed below
    {
        "preservim/nerdcommenter"
    },

    {
        'windwp/nvim-autopairs',
        config = function()
            require("nvim-autopairs").setup {
                event = { "BufReadPre", "BufNewFile" },
                opts = {
                    enable_check_bracket_line = false, -- Don't add pairs if it already has a close pair in the same line
                    ignored_next_char = "[%w%.]",      -- will ignore alphanumeric and `.` symbol
                    check_ts = true,                   -- use treesitter to check for a pair.
                    ts_config = {
                        lua = { "string" },            -- it will not add pair on that treesitter node
                        javascript = { "template_string" },
                        java = false,                  -- don't check treesitter on java
                    },
                },
            }
        end
    },

    {
        'phaazon/hop.nvim',
        branch = 'v2', -- optional but strongly recommended
        config = function()
            -- you can configure Hop the way you like here; see :h hop-config
            require 'hop'.setup {
                keys = 'etovxqpdygfblzhckisuran',
                case_insensitive = false,
                multi_windows = true,
            }
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
        config = function()
            require("auto-save").setup {
                execution_message = false,
            }
        end,
    },
    {
        'ojroques/nvim-osc52'
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
        "kylechui/nvim-surround",
        version = "*", -- Use for stability; omit to use `main` branch for the latest features
        event = "VeryLazy",
        config = function()
            require("nvim-surround").setup({
                -- Configuration here, or leave empty to use defaults
                keymaps = {
                    visual = 's',
                    visual_line = 'S'
                }
            })
        end
    },
    {
    "LintaoAmons/cd-project.nvim",
        -- Don't need call the setup function if you think you are good with the default configuration
        tag = "v0.6.1", -- Optional, You can also use tag to pin the plugin version for stability
        init = function() -- use init if you want enable auto_register_project, otherwise config is good
        require("cd-project").setup({
            -- this json file is acting like a database to update and read the projects in real time.
            -- So because it's just a json file, you can edit directly to add more paths you want manually
            projects_config_filepath = vim.fs.normalize(vim.fn.stdpath("config") .. "/cd-project.nvim.json"),
            -- this controls the behaviour of `CdProjectAdd` command about how to get the project directory
            project_dir_pattern = { ".git", ".gitignore", "Cargo.toml", "package.json", "go.mod" },
            choice_format = "both", -- optional, you can switch to "name" or "path"
            projects_picker = "telescope", -- optional, you can switch to `telescope`
            auto_register_project = true, -- optional, toggle on/off the auto add project behaviour
            -- do whatever you like by hooks
            hooks = {
            -- Run before cd to project, add a bookmark here, then can use `CdProjectBack` to switch back
            -- {
            --   trigger_point = "BEFORE_CD",
            --   callback = function(_)
            --     vim.print("before cd project")
            --     require("bookmarks").api.mark({name = "before cd project"})
            --   end,
            -- },
            -- Run after cd to project, find and open a file in the target project by smart-open
            -- {
            --   callback = function(_)
            --     require("telescope").extensions.smart_open.smart_open({
            --       cwd_only = true,
            --       filename_first = false,
            --     })
            --   end,
            -- },
            }
        })
        end,
    },
    {
        'm4xshen/autoclose.nvim'
    }
}
