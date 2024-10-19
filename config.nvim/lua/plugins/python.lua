return {
    {
        "mfussenegger/nvim-dap-python",
        config = function()
            local pythonPath = function()
                return require("venv-selector").python()
            end
            require('dap-python').setup(pythonPath())
            table.insert(require('dap').configurations.python, {
                type = 'debugpy',
                request = 'launch',
                name = 'Python Debug Current File',
                program = '${file}',
                stopOnEntry = true,
                console = 'integratedTerminal',
            })
        end
    },
    {
        "linux-cultist/venv-selector.nvim",
        config = function()
            require("venv-selector").setup {
                settings = {
                search = {
                    bare_envs = {
                        command = "fd python$ ~/.venv/",
                    },
                },
                },
            }
        end
    },
    {
        "lukas-reineke/cmp-under-comparator"
    }
}
