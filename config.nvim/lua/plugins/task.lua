return {
  {
    "stevearc/overseer.nvim",
    keys = {
      {
        "<leader>ll",
        "<cmd>OverseerQuickAction open float<cr>",
      },
      {
        "<leader>lL",
        "<cmd>OverseerToggle<cr>",
      },
      {
        "<leader>lm",
        "<cmd>OverseerRunCmd<cr>",
      },
      {
        "<leader>lr",
        "<cmd>OverseerRun<cr>",
      },
    },
    opts = {
      -- TODO: Find some way to set for `_disposed_` and `on_complete_dispose`.
      task_list = {
        bindings = {
          ["<c-k>"] = "<c-w><c-k>",
          ["<c-j>"] = "<c-w><c-j>",
          ["<c-l>"] = "<c-w><c-l>",
          ["<c-h>"] = "<c-w><c-h>",
          ["<cr>"] = "TogglePreview",
          ["<c-cr>"] = "OpenFloat",
          ["<d-cr>"] = "OpenFloat",
          ["<c-s-r>"] = "OpenVsplit",
          ["a"] = "RunAction",
        },
        direction = "left",
      },
      task_editor = {
        bindings = {
          i = {
            ["<c-cr>"] = "Submit",
            ["<d-cr>"] = "Submit",
          },
          n = {
            ["<c-cr>"] = "Submit",
            ["<d-cr>"] = "Submit",
          },
        },
      },
    },
  },
}
