-- AI completions.
return {
  -- from ai store.
  {
    "github/copilot.vim",
  },
  -- tencent copilot (gongfeng).
  --[[{
    "copilot.vim",
  },]]
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    -- commit = "e98fa46", -- set this if you want to always pull the latest change
    keys = {
      {
        "<leader>aa",
        "<cmd>AvanteChat<CR>",
        mode = { "n" },
        -- mode = { "n", "i" }, -- it could not be insert mode. It's causing space being very slow.
        desc = "Start avante Chat",
      },
      {
        "<leader>ae",
        "V<cmd>AvanteEdit<CR>",
        mode = { "n" },
        desc = "Start code completion.",
      },
    },
    opts = {
      ---@alias Provider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | string
      provider = "openrouter_claude_3_5", -- Recommend using Claude
      -- auto_suggestions_provider = "4o", -- Since auto-suggestions are a high-frequency operation and therefore expensive, it is recommended to specify an inexpensive provider or even a free provider: copilot
      vendors = {
        -- Weak support for local llms like ollama. But it's unnecessary for now.
        -- They are just too weak to do anything.
        ["4omini"] = {
          __inherited_from = "openai",
          api_key_name = "OPENAI_API_KEY",
          model = "gpt-4o-mini",
        },
        openrouter_gemini_pro = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          -- model = "openrouter/auto",
          model = "google/gemini-2.5-pro-preview",
          max_tokens = 102400,
          -- timeout = 30000,
          disable_tools = true,
        },
        openrouter_gemini_flash = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          -- model = "openrouter/auto",
          model = "google/gemini-2.5-flash-preview",
          max_tokens = 10240,
          -- timeout = 30000,
          disable_tools = true,
        },
        openrouter_claude_3_5 = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          -- model = "openrouter/auto",
          model = "anthropic/claude-3.5-sonnet",
          max_tokens = 10240,
          -- timeout = 30000,
          disable_tools = true,
        },
        deepseek = {
          __inherited_from = "openai",
          endpoint = "https://api.deepseek.com/",
          api_key_name = "DEEPSEEK_API_KEY",
          model = "deepseek-chat",
        },
        o1 = {
          __inherited_from = "azure",
          endpoint = "https://vlaa-openai-eastus2.openai.azure.com/",
          deployment = "o1-preview-0912-nofilter",
          model = "o1-preview-0912-nofilter",
          api_key_name = "AZURE_OPENAI_O1_API_KEY",
          api_version = "2024-02-15-preview",
          timeout = 300000,
          max_tokens = 128000,
        },
        ["azure4omini"] = {
          __inherited_from = "azure",
          endpoint = "https://openai-vlaa-eastus.openai.azure.com/",
          deployment = "gpt-4o-mini-0718-nofilter",
          model = "gpt-4o-mini-0718-nofilter",
          api_key_name = "AZURE_OPENAI_API_KEY",
          api_version = "2024-02-15-preview",
          timeout = 30000,
          temperature = 0.7,
          max_tokens = 10000,
        },
      },
      behaviour = {
        auto_suggestions = false, -- Experimental stage
        auto_set_highlight_group = true,
        auto_set_keymaps = true,
        auto_apply_diff_after_generation = false,
        support_paste_from_clipboard = false,
      },
      mappings = {
        --- @class AvanteConflictMappings
        diff = {
          ours = "co",
          theirs = "ct",
          all_theirs = "ca",
          both = "cb",
          cursor = "cc",
          next = "]]",
          prev = "[[",
        },
        submit = {
          normal = "<CR>",
          insert = "<C-s>",
        },
        sidebar = {
          apply_all = "A",
          apply_cursor = "a",
          close = { "q" }, -- <Esc> should be doing nothing.
          --[[switch_windows = "<Tab>",
          reverse_switch_windows = "<S-Tab>",]]
        },
      },
      hints = { enabled = false },
      windows = {
        ---@type "right" | "left" | "top" | "bottom"
        position = "right", -- the position of the sidebar
        wrap = true, -- similar to vim.o.wrap
        width = 30, -- default % based on available width
        sidebar_header = {
          enabled = false,
          align = "center", -- left, center, right for title
          rounded = true,
        },
      },
      highlights = {
        ---@type AvanteConflictHighlights
        diff = {
          current = "DiffText",
          incoming = "DiffAdd",
        },
      },
      --- @class AvanteConflictUserConfig
      diff = {
        autojump = true,
        ---@type string | fun(): any
        list_opener = "copen",
      },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      -- "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      -- "zbirenbaum/copilot.lua", -- for providers='copilot'
      {
        -- Make sure to set this up properly if you have lazy=true
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
