return {
    {
        "mfussenegger/nvim-dap",
        config = function()
            local dap = require('dap')
            -- setup keymap before debug session begins.
            dap.listeners.before['event_initialized']['nvim-dap-noui'] = function(_, _)
                vim.print('Debug Session intialized ')
                NoUIKeyMap()
            end
            -- unmap keymap after that.
            dap.listeners.before['event_terminated']['nvim-dap-noui'] = function(_, _)
                vim.print('Debug Session terminated.')
                NoUIUnmap()
            end
            -- dap.listeners.before['event_terminated']['nvim-dap-noui'] = dap.listeners.before['event_stopped']['nvim-dap-noui'] 
        end
    },
    --[[{
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"
        }
    },]]
    {
        "nvim-telescope/telescope-dap.nvim",
        config = function()
            require('telescope').load_extension('dap')
        end
    }
}
