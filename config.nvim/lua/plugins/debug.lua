return {
    {
        "mfussenegger/nvim-dap"
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
