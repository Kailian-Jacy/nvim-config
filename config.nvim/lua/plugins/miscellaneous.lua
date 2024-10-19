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
        opts = {
            colorscheme = "dracula",
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
                local line, col = unpack(vim.api.nvim_win_get_cursor(0))
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
                        winhighlight = 'NormalFloat:TelescopeNormal,FloatBorder:TelescopeBorder',
                    },
                    documentation = {
                        border = 'rounded',
                        winhighlight = 'NormalFloat:TelescopeNormal,FloatBorder:TelescopeBorder',
                    }
                },
                mapping = cmp.mapping.preset.insert {
                    ['kk'] = cmp.mapping.confirm({
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true,
                    }),
                    ['<Tab>'] = function(fallback)
                        if not cmp.select_next_item() then
                            if vim.bo.buftype ~= 'prompt' and has_words_before() then
                                cmp.complete()
                            else
                                fallback()
                            end
                        end
                    end,
                    ['<S-Tab>'] = function(fallback)
                        if not cmp.select_prev_item() then
                            if vim.bo.buftype ~= 'prompt' and has_words_before() then
                                cmp.complete()
                            else
                                fallback()
                            end
                        end
                    end,
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
                sources = {
                    { name = 'buffer' }
                }
            });
            -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
            cmp.setup.cmdline(':', {
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
        "williamboman/mason.nvim",
        opts = {
            ensure_installed = {}
        },
    },

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

    {
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
    },
    {
        "okuuva/auto-save.nvim",
        config = function()
            require("auto-save").setup {
                execution_message = {
                    enabled = false,
                },
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
    }
}
