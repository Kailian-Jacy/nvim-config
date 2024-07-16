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

	-- disable trouble
	-- { "folke/trouble.nvim", enabled = false },

	-- override nvim-cmp and add cmp-emoji
	{
		"hrsh7th/nvim-cmp",
		dependencies = { "hrsh7th/cmp-emoji" },
		opts = function(_, opts)
			table.insert(opts.sources, { name = "emoji" })

            local cmp = require("cmp")
            local has_words_before = function()
                unpack = unpack or table.unpack
                local line, col = unpack(vim.api.nvim_win_get_cursor(0))
                return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match('%s') == nil
            end
            return {
                auto_brackets = {}, -- configure any filetype to auto add brackets
                completion = {
                    completeopt = "menu,menuone,noinsert" .. (true and "" or ",noselect"),
                },
                mapping = cmp.mapping.preset.insert {
                        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                        ['<C-f>'] = cmp.mapping.scroll_docs(4),
                        ['<C-Space>'] = cmp.mapping.complete(),
                        ['<C-e>'] = cmp.mapping.abort(),
                        ['<CR>'] = cmp.mapping.confirm({  -- <TAB>
                            -- behavior = cmp.ConfirmBehavior.Replace,  -- if active, replaces succeeding text
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
                        priority = 100,
                    },
                    {name = 'buffer'}, {name = 'nvim_lsp'},
                    {name = "nvim_lua"}, {name = "path"},
                },
            }
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
			ensure_installed = {
				"stylua",
				"shellcheck",
				"shfmt",
				"flake8",
			},
		},
	},

	{
        "preservim/nerdcommenter"
	},

	{
        'windwp/nvim-autopairs',
        config = function()
            require("nvim-autopairs").setup{
                event = { "BufReadPre", "BufNewFile" },
                opts = {
                    enable_check_bracket_line = false, -- Don't add pairs if it already has a close pair in the same line
                    ignored_next_char = "[%w%.]", -- will ignore alphanumeric and `.` symbol
                    check_ts = true, -- use treesitter to check for a pair.
                    ts_config = {
                        lua = { "string" }, -- it will not add pair on that treesitter node
                        javascript = { "template_string" },
                        java = false, -- don't check treesitter on java
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
                require'hop'.setup {
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
        dependencies = { {'nvim-tree/nvim-web-devicons'}}
    },
    {
        "hrsh7th/cmp-cmdline",
        config = function()
            local cmp = require("cmp")
            cmp.setup.cmdline(':', {
            mapping = cmp.mapping.preset.cmdline(),
            sources = cmp.config.sources({
                { name = 'path' }
            }, {
                {
                    name = 'cmdline',
                    option = {
                        ignore_cmds = { 'Man', '!' }
                    }
                }
            })
            })
        end
    },
    {
        -- plugin: auto-save.nvim
        -- function: auto save changes
        -- src: https://github.com/pocco81/auto-save.nvim
        "Pocco81/auto-save.nvim",
    }
}
