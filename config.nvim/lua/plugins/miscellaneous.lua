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
		---@param opts cmp.ConfigSchema
		opts = function(_, opts)
			table.insert(opts.sources, { name = "emoji" })
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
			},
		},
	},

	-- add pyright to lspconfig
	{
		"neovim/nvim-lspconfig",
		---@class PluginLspOpts
		opts = {
			---@type lspconfig.options
			servers = {
				-- pyright will be automatically installed with mason and loaded with lspconfig
				pyright = {},
			},
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
				"vim",
				"yaml",
				"json",
				"json5",
			},
		},
	},

	--	 -- since `vim.tbl_deep_extend`, can only merge tables and not lists, the code above
	--	 -- would overwrite `ensure_installed` with the new value.
	--	 -- If you'd rather extend the default config, use the code below instead:
	--	 {
	--		 "nvim-treesitter/nvim-treesitter",
	--		 opts = function(_, opts)
	--			 -- add tsx and treesitter
	--			 vim.list_extend(opts.ensure_installed, {
	--				 "tsx",
	--				 "typescript",
	--			 })
	--		 end,
	--	 },

	-- the opts function can also be used to change the default opts:
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = function(_, opts)
			table.insert(opts.sections.lualine_x, "😄")
		end,
	},

	-- or you can return new options to override all the defaults
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = function()
			return {
				--[[add your custom lualine config here]]
			}
		end,
	},

	-- use mini.starter instead of alpha
	{ import = "lazyvim.plugins.extras.ui.mini-starter" },

	-- add jsonls and schemastore packages, and setup treesitter for json, json5 and jsonc
	{ import = "lazyvim.plugins.extras.lang.json" },

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
		"numToStr/Comment.nvim",
		opts = {
				-- add any options here
		},
		lazy = false,
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
	    "pocco81/auto-save.nvim"
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
    }
}
