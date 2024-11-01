return {
    {
        "Mofiqul/dracula.nvim",
        config = function ()
            require("dracula").setup({
                colors = {
                    -- selection = "#0F3460",
                    selection = "#2D4263",
                    visual = "#2D4263",
                    bg = ""
                },
                transparent_bg = true,
                italic_comment = true,
                overrides = {
                    Pmenu = { bg = "#363948" },
                    PmenuSbar = { bg = "#363948" },
                    -- Completion/documentation Pmenu border color when using bordered windows
                    CmpPmenuBorder = { link = "NonText" },
                    -- Telescope borders
                    TelescopeBorder = { link = "Constant" },
                    WinSeparator = { fg = "#565f89" },
                }
            })
        end
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
        end,
    },
    {
        "xiyaowong/transparent.nvim",
        config = function()
            -- Optional, you don't have to run setup.
            require("transparent").setup({
            -- table: default groups
            groups = {
                'Normal', 'NormalNC', 'Comment', 'Constant', 'Special', 'Identifier',
                'Statement', 'PreProc', 'Type', 'Underlined', 'Todo', 'String', 'Function',
                'Conditional', 'Repeat', 'Operator', 'Structure', 'LineNr', 'NonText',
                'SignColumn', 'CursorLine', 'CursorLineNr', 'StatusLine', 'StatusLineNC',
                'EndOfBuffer',
            },
            -- table: additional groups that should be cleared
            extra_groups = {},
            -- table: groups you don't want to clear
            exclude_groups = {
                    "TelescopeSelection",
                    "TelescopeMultiSelection",
                    "TelescopePreviewLine"
                },
            -- function: code to be executed after highlight groups are cleared
            -- Also the user event "TransparentClear" will be triggered
            on_clear = function() end,
            })
            require("transparent").clear_prefix("Telescope")
        end
    },
    {
        "folke/noice.nvim",
        config = function()
            --[[require("lualine").setup({
                sections = {
                    lualine_x = {
                        {
                            require("noice").api.statusline.mode.get,
                            cond = require("noice").api.statusline.mode.has,
                            color = { fg = "#ff9e64" },
                        },
                    },
                },
            })
            ]]--
            require("noice").setup({
                views = {
                    mini = {
                        win_options = {
                            winblend = 0
                        }
                    },
                    cmdline_popup = {
                        position = {
                            row = 5,
                            col = "50%",
                        },
                        size = {
                            width = 60,
                            height = "auto",
                        },
                    },
                    --[[
                    popupmenu = {
                        relative = "editor",
                        position = {
                            row = 8,
                            col = "50%",
                        },
                        size = {
                            width = 60,
                            height = 10,
                        },
                        border = {
                            style = "rounded",
                            padding = { 0, 1 },
                        },
                        win_options = {
                            winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
                        },
                    },]]
                },
            })
        end,
    },
    -- the opts function can also be used to change the default opts:
    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        --[[opts = function(_, opts)
            local trouble = require("trouble")
            local symbols = trouble.statusline({
                mode = "lsp_document_symbols",
                groups = {},
                title = false,
                filter = { range = true },
                format = "{kind_icon}{symbol.name:Normal}",
                -- The following line is needed to fix the background color
                -- Set it to the lualine section you want to use
                hl_group = "lualine_c_normal",
            })
            table.insert(opts.sections.lualine_c, {
                symbols.get,
                cond = symbols.has,
            })
        end,]]
        config = function()
           local theme = {
                inactive = {
                    a = { fg = nil, bg = nil },
                    b = { fg = nil, bg = nil },
                    c = { fg = nil, bg = nil },
                },
                visual = {
                    a = { fg = nil, bg = nil },
                    b = { fg = nil, bg = nil },
                    c = { fg = nil, bg = nil },
                },
                replace = {
                    a = { fg = nil, bg = nil },
                    b = { fg = nil, bg = nil },
                    c = { fg = nil, bg = nil },
                },
                normal = {
                    a = { fg = nil, bg = nil },
                    b = { fg = nil, bg = nil },
                    c = { fg = nil, bg = nil },
                },
                insert = {
                    a = { fg = nil, bg = nil },
                    b = { fg = nil, bg = nil },
                    c = { fg = nil, bg = nil },
                },
                command = {
                    a = { fg = nil, bg = nil },
                    b = { fg = nil, bg = nil },
                    c = { fg = nil, bg = nil },
                }
           };
           require("lualine").setup({
                options = {
                    theme = theme
                },
                sections = {
                    lualine_a = {},
                    lualine_b = {},
                    lualine_c = {},
                    lualine_x = {},
                    lualine_y = {},
                    lualine_z = {{'filename', path=1}}
                }
            })
        end
    },
}
