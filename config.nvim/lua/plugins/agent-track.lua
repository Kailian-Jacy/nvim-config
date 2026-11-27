-- Local plugin: live subcommit tracking, causal diff review, and non-intrusive sync.
-- Lives in <config>/plugins/agent-track; loaded as a local `dir` plugin.
return {
  {
    "agent-track",
    dir = vim.fn.stdpath("config") .. "/plugins/agent-track",
    event = "VeryLazy",
    cmd = { "AgentTrack" },
    opts = {},
    keys = {
      { "<leader>atr", function() require("agent-track.reviewer").panel() end, desc = "AgentTrack: Review panel" },
      { "<leader>atl", "<cmd>AgentTrack list<cr>", desc = "AgentTrack: Sessions" },
      { "<leader>ato", function() require("agent-track.reviewer").open() end, desc = "AgentTrack: Open diff" },
      { "<leader>ats", "<cmd>AgentTrack sync approved<cr>", desc = "AgentTrack: Sync approved" },
      { "<leader>atu", "<cmd>AgentTrack undo<cr>", desc = "AgentTrack: Undo sync" },
      { "<leader>atf", "<cmd>AgentTrack fetch<cr>", desc = "AgentTrack: Fetch subcommits" },
      { "<leader>ati", "<cmd>AgentTrack status<cr>", desc = "AgentTrack: Status" },
    },
    config = function(_, opts)
      require("agent-track").setup(opts)
    end,
  },
}
