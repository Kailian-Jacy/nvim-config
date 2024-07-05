return {
    {
        "Mofiqul/dracula.nvim",
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
        "folke/noice.nvim",
        config = function()
            require("lualine").setup({
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
            require("noice").setup({
                views = {
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
                    },
                },
            })
        end,
    },
}
