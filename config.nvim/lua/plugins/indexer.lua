return {
    {
        "nvim-telescope/telescope-file-browser.nvim",
        dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
        config = function()
            require("telescope").setup({
                extensions = {
                    file_browser = {
                        theme = "ivy",
                        -- disables netrw and use telescope-file-browser in its place
                        hijack_netrw = true,
                        --mappings = {
                        --["i"] = {
                        ---- your custom insert mode mappings
                        --},
                        --["n"] = {
                        ---- your custom normal mode mappings
                        --},
                        --},
                    },
                },
                require("telescope").load_extension("file_browser"),
            })
        end,
    },
    {
        "stevearc/aerial.nvim",
        config = function()
            require("aerial").setup({
                backends = { "lsp", "treesitter", "markdown", "asciidoc", "man" },
                -- optionally use on_attach to set keymaps when aerial has attached to a buffer
                require("telescope").setup({
                    extensions = {
                        aerial = {
                            -- Display symbols as <root>.<parent>.<symbol>
                            show_nesting = {
                                ["_"] = false, -- This key will be the default
                                json = true, -- You can set the option for specific filetypes
                                yaml = true,
                            },
                        },
                    },
                }),
            })
        end,
    },
    {
        "gorbit99/codewindow.nvim",
        version = "*",
        config = function()
            local codewindow = require("codewindow")
            codewindow.setup()
            codewindow.apply_default_keybinds()
        end,
    },
}
