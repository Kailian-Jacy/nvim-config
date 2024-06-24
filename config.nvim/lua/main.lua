-- Install lazy.nvim if it's not installed.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end

-- Append lazy path to runtime path.
vim.opt.rtp:prepend(lazypath)

-- Load lazy.nvim
require("lazy").setup({
{
    'nvim-telescope/telescope.nvim', tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },
	config = function () 
		  require('telescope').setup{
		  defaults = {
			-- Default configuration for telescope goes here:
			-- config_key = value,
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
			  i = {
				-- map actions.which_key to <C-h> (default: <C-/>)
				-- actions.which_key shows the mappings for your picker,
				-- e.g. git_{create, delete, ...}_branch for the git_branches picker
				--["<C-h>"] = "which_key"
			  }
			}
		  },
		  pickers = {
			-- Default configuration for builtin pickers goes here:
			-- picker_name = {
			--   picker_config_key = value,
			--   ...
			-- }
			-- Now the picker_config_key will be applied every time you call this
			-- builtin picker
		  },
		  extensions = {
			-- Your extension configuration goes here:
			-- extension_name = {
			--   extension_config_key = value,
			-- }
			-- please take a look at the readme of the extension you want to configure
		  }
		}
	end
},
{
    "lewis6991/gitsigns.nvim",
	config = function ()
	  require('gitsigns').setup {
	  signs = {
		add          = { text = '┃' },
		change       = { text = '┃' },
		delete       = { text = '_' },
		topdelete    = { text = '‾' },
		changedelete = { text = '~' },
		untracked    = { text = '┆' },
	  },
	  signcolumn = true,  -- Toggle with `:Gitsigns toggle_signs`
	  numhl      = false, -- Toggle with `:Gitsigns toggle_numhl`
	  linehl     = false, -- Toggle with `:Gitsigns toggle_linehl`
	  word_diff  = false, -- Toggle with `:Gitsigns toggle_word_diff`
	  watch_gitdir = {
		follow_files = true
	  },
	  auto_attach = true,
	  attach_to_untracked = false,
	  current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
	  current_line_blame_opts = {
		virt_text = true,
		virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
		delay = 1000,
		ignore_whitespace = false,
		virt_text_priority = 100,
	  },
	  current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',
	  sign_priority = 6,
	  update_debounce = 100,
	  status_formatter = nil, -- Use default
	  max_file_length = 40000, -- Disable if file is longer than this (in lines)
	  preview_config = {
		-- Options passed to nvim_open_win
		border = 'single',
		style = 'minimal',
		relative = 'cursor',
		row = 0,
		col = 1
		  },
		}
	end
},
{
    "tpope/vim-fugitive",
},
{
    'Mofiqul/dracula.nvim',
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
    event = "InsertEnter",
    opts = {}
},
{
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
        theme = 'dracula-nvim'
    }
},
{
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function () 
      local configs = require("nvim-treesitter.configs")

      configs.setup({
          ensure_installed = { "c", "lua", "vim", "vimdoc", "toml", "yaml", "json", "javascript", "html", "go", "rust", "gomod", "gosum",
			"latex", "python", "sql", "cpp", "csv", "bash"
		  },
          sync_install = false,
          highlight = { enable = true },
          indent = { enable = true },  
        })
    end
},
--{
    --'ms-jpq/chadtree',
    --branch = 'chad',
    --config = function()
        --vim.keymap.set('n', '<leader>e', '<cmd>CHADopen<CR>')
        --local chadtree_settings = {
            --xdg = false,
            --view = {
                --width = 60
            --},
            --ignore = {
                --name_exact = {"node_modules"}
            --}
        --}
        --vim.api.nvim_set_var('chadtree_settings', chadtree_settings)
    --end
--},
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
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "dracula",
    },
},
{
    "scrooloose/nerdcommenter"
},
{
    'nvim-treesitter/nvim-treesitter-context',
    config  = function() 
        require'treesitter-context'.setup{
        enable = true, 
        max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
        min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
        line_numbers = true,
        multiline_threshold = 20, -- Maximum number of lines to show for a single context
        trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
        mode = 'cursor',  -- Line used to calculate context. Choices: 'cursor', 'topline'
        -- Separator between context and content. Should be a single character string, like '-'.
        -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
        separator = nil,
        zindex = 20, -- The Z-index of the context window
        on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching
    }
    end
},
{
    "junegunn/rainbow_parentheses.vim"
},
{
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup {
      view = {
        width = 30,
      },
      renderer = {
        group_empty = true,
      },
      filters = {
        dotfiles = true,
      },
      on_attach = my_on_attach
    }
    end,
},
{
	"hrsh7th/nvim-cmp",
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-nvim-lua",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-cmdline",
		"saadparwaiz1/cmp_luasnip",
		"L3MON4D3/LuaSnip",
	},
	config = function()
	local cmp = require("cmp")
	vim.opt.completeopt = { "menu", "menuone", "noselect" }

	cmp.setup({
		snippet = {
			expand = function(args)
				require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
			end,
		},
		window = {
			-- completion = cmp.config.window.bordered(),
			-- documentation = cmp.config.window.bordered(),
		},
		mapping = cmp.mapping.preset.insert({
			["<C-b>"] = cmp.mapping.scroll_docs(-4),
			["<C-f>"] = cmp.mapping.scroll_docs(4),
			["<Tab>"] = cmp.mapping.select_next_item(),
			["<S-Tab>"] = cmp.mapping.select_prev_item(),
			["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
			["<C-e>"] = cmp.mapping.abort(),
		}),
		sources = cmp.config.sources({
			{ name = "nvim_lsp" },
			{ name = "nvim_lua" },
			{ name = "luasnip" }, -- For luasnip users.
			-- { name = "orgmode" },
			{ name = "buffer" },
			{ name = "path" },
		}),
	})

	cmp.setup.cmdline(":", {
		mapping = cmp.mapping.preset.cmdline(),
		sources = cmp.config.sources({
			{ name = "path" },
		}, {
			{ name = "cmdline" },
		}),
	})
	end
},
{
	"neovim/nvim-lspconfig",
	config = function() 
		local maps = vim.keymap.set
	    local opts_l = { silent = true, noremap = true }

		maps('n', 'gh', vim.lsp.buf.hover, opts_l)
		--maps('n', 'gd', vim.lsp.buf.definition, opts_l)
		--maps('i', '<C-k>', vim.lsp.buf.signature_help, opts_l)

		local capabilities = require('cmp_nvim_lsp').default_capabilities()
		require('lspconfig').rust_analyzer.setup {
		  -- Server-specific settings. See `:help lspconfig-setup`
		  capabilities = capabilities
		}
		require('lspconfig').clangd.setup {
		  -- Server-specific settings. See `:help lspconfig-setup`
		  capabilities = capabilities
		}
		require('lspconfig').gopls.setup {
		  -- Server-specific settings. See `:help lspconfig-setup`
		  capabilities = capabilities,
		  settings = {
		  gopls = {
			  analyses = {
				unusedparams = true,
			  },
			  staticcheck = true,
			  gofumpt = true,
			},
		  },
		}
	end
},
{
	"pocco81/dap-buddy.nvim"
},
{ "rcarriga/nvim-dap-ui", dependencies = {"mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"} },
{
	"nvim-telescope/telescope-dap.nvim",
	config = function() 
		require('telescope').load_extension('dap')
	end
},
{	
	"theHamsta/nvim-dap-virtual-text",
	config = function() 
		require("nvim-dap-virtual-text").setup {
		    enabled = true,                        -- enable this plugin (the default)
		    enabled_commands = true,               -- create commands DapVirtualTextEnable, DapVirtualTextDisable, DapVirtualTextToggle, (DapVirtualTextForceRefresh for refreshing when debug adapter did not notify its termination)
		    highlight_changed_variables = true,    -- highlight changed values with NvimDapVirtualTextChanged, else always NvimDapVirtualText
		    highlight_new_as_changed = false,      -- highlight new variables in the same way as changed variables (if highlight_changed_variables)
		    show_stop_reason = true,               -- show stop reason when stopped for exceptions
		    commented = false,                     -- prefix virtual text with comment string
		    only_first_definition = true,          -- only show virtual text at first definition (if there are multiple)
		    all_references = false,                -- show virtual text on all all references of the variable (not only definitions)
		    clear_on_continue = false,             -- clear virtual text on "continue" (might cause flickering when stepping)
		    --- A callback that determines how a variable is displayed or whether it should be omitted
		    --- @param variable Variable https://microsoft.github.io/debug-adapter-protocol/specification#Types_Variable
		    --- @param buf number
		    --- @param stackframe dap.StackFrame https://microsoft.github.io/debug-adapter-protocol/specification#Types_StackFrame
		    --- @param node userdata tree-sitter node identified as variable definition of reference (see `:h tsnode`)
		    --- @param options nvim_dap_virtual_text_options Current options for nvim-dap-virtual-text
		    --- @return string|nil A text how the virtual text should be displayed or nil, if this variable shouldn't be displayed
		    display_callback = function(variable, buf, stackframe, node, options)
		      if options.virt_text_pos == 'inline' then
			return ' = ' .. variable.value
		      else
			return variable.name .. ' = ' .. variable.value
		      end
		    end,
		    -- position of virtual text, see `:h nvim_buf_set_extmark()`, default tries to inline the virtual text. Use 'eol' to set to end of line
		    virt_text_pos = vim.fn.has 'nvim-0.10' == 1 and 'inline' or 'eol',

		    -- experimental features:
		    all_frames = false,                    -- show virtual text for all stack frames not only current. Only works for debugpy on my machine.
		    virt_lines = false,                    -- show virtual lines instead of virtual text (will flicker!)
		    virt_text_win_col = nil                -- position the virtual text at a fixed window column (starting from the first text column) ,
							   -- e.g. 80 to position at column 80, see `:h nvim_buf_set_extmark()`
		}
	end
},
{
	"akinsho/toggleterm.nvim",
	config = function()
			--require("toggleterm").setup{
  ---- size can be a number or function which is passed the current terminal
  --size = 20 | function(term)
    --if term.direction == "horizontal" then
      --return 15
    --elseif term.direction == "vertical" then
      --return vim.o.columns * 0.4
    --end
  --end,
  --open_mapping = [[<c-\>]], -- or { [[<c-\>]], [[<c-¥>]] } if you also use a Japanese keyboard.
  --on_create = fun(t: Terminal), -- function to run when the terminal is first created
  --on_open = fun(t: Terminal), -- function to run when the terminal opens
  --on_close = fun(t: Terminal), -- function to run when the terminal closes
  --on_stdout = fun(t: Terminal, job: number, data: string[], name: string) -- callback for processing output on stdout
  --on_stderr = fun(t: Terminal, job: number, data: string[], name: string) -- callback for processing output on stderr
  --on_exit = fun(t: Terminal, job: number, exit_code: number, name: string) -- function to run when terminal process exits
  --hide_numbers = true, -- hide the number column in toggleterm buffers
  --shade_filetypes = {},
  --autochdir = false, -- when neovim changes it current directory the terminal will change it's own when next it's opened
  --highlights = {
    ---- highlights which map to a highlight group name and a table of it's values
    ---- NOTE: this is only a subset of values, any group placed here will be set for the terminal window split
    --Normal = {
      --guibg = "<VALUE-HERE>",
    --},
    --NormalFloat = {
      --link = 'Normal'
    --},
    --FloatBorder = {
      --guifg = "<VALUE-HERE>",
      --guibg = "<VALUE-HERE>",
    --},
  --},
  --shade_terminals = true, -- NOTE: this option takes priority over highlights specified so if you specify Normal highlights you should set this to false
  --shading_factor = '<number>', -- the percentage by which to lighten terminal background, default: -30 (gets multiplied by -3 if background is light)
  --start_in_insert = true,
  --insert_mappings = true, -- whether or not the open mapping applies in insert mode
  --terminal_mappings = true, -- whether or not the open mapping applies in the opened terminals
  --persist_size = true,
  --persist_mode = true, -- if set to true (default) the previous terminal mode will be remembered
  --direction = 'vertical' | 'horizontal' | 'tab' | 'float',
  --close_on_exit = true, -- close the terminal window when the process exits
   ---- Change the default shell. Can be a string or a function returning a string
  --shell = vim.o.shell,
  --auto_scroll = true, -- automatically scroll to the bottom on terminal output
  ---- This field is only relevant if direction is set to 'float'
  --float_opts = {
    ---- The border key is *almost* the same as 'nvim_open_win'
    ---- see :h nvim_open_win for details on borders however
    ---- the 'curved' border is a custom border type
    ---- not natively supported but implemented in this plugin.
    --border = 'single' | 'double' | 'shadow' | 'curved' | ... other options supported by win open
    ---- like `size`, width, height, row, and col can be a number or function which is passed the current terminal
    --width = <value>,
    --height = <value>,
    --row = <value>,
    --col = <value>,
    --winblend = 3,
    --zindex = <value>,
    --title_pos = 'left' | 'center' | 'right', position of the title of the floating window
  --},
  --winbar = {
    --enabled = false,
    --name_formatter = function(term) --  term: Terminal
      --return term.name
    --end
  --},
--}
	end
}
})

-- Set the hop
local hop = require('hop')
local directions = require('hop.hint').HintDirection
vim.keymap.set('', 't', function()
  hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true, hint_offset = -1 })
end, {remap=true})
vim.keymap.set('', 'T', function()
  hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true, hint_offset = 1 })
end, {remap=true})


-- Set the nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true
local function my_on_attach(bufnr)
  local api = require "nvim-tree.api"

  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  -- default mappings
  api.config.mappings.default_on_attach(bufnr)

  -- custom mappings
  vim.keymap.set('n', 'C', api.tree.change_root_to_parent, opts('Up'))
  vim.keymap.set('n', 'b', api.tree.change_root_to_node, opts('Up'))
  vim.keymap.set('n', '?', api.tree.toggle_help, opts('Help'))
end

