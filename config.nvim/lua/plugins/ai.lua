
-- AI completions.
return {
  (
    -- Detect and decide to use which version of copilot.
    -- Tencent Gongfeng > Github copilot.
    function()
      -- Copilot: detect to choose if to use local plugin.

      -- Use tencent gongfeng.
      -- local gongfeng_dir = vim.fn.stdpath("config") .. "/pack/gongfeng/start/vim"
      -- Use AI store: to config: https://docs.cp.acce.dev/ides/vim.html
      local aistore_dir = vim.fn.stdpath("config") .. "/pack/aistore/start/copilot.vim"

      local copilot = {}
      if vim.fn.isdirectory(aistore_dir) == 1 then
        copilot = {
          "copilot.vim",
          dir = aistore_dir,
          config = function()
            vim.g.copilot_auth_provider_url = "https://cp.acce.dev"
          end
        }
      else
        copilot = {
          "github/copilot.vim",
        }
      end
      -- Merge with default settings.
      local default = {
        enabled = vim.g.modules.copilot and vim.g.modules.copilot.enabled,
        lazy = false,
        keys = {
          {
            "<D-CR>",
            function()
              vim.api.nvim_feedkeys(
                vim.fn["copilot#Accept"](function()
                  return vim.api.nvim_replace_termcodes("<D-CR>", true, true, true) -- should be "n" mode to break infinite loop.
                end),
                "n",
                true
              )
            end,
            mode = { "i" },
            desc = "Accept complete copilot suggestion",
          }
        }
      }

      copilot = vim.tbl_deep_extend("keep", copilot, default)
      return copilot
    end
  )(),
  {
    -- Quick one-key AI modification helper.
    -- Addresses nvim-config#14: A quick one-key ai modification helper.
    -- Philosophy: keep it simple, select code → one key → AI edits in place.
    "robitx/gp.nvim",
    lazy = true,
    keys = {
      -- Primary: one-key rewrite (implements pseudocode, fixes based on comments).
      {
        "<leader>ae",
        "V:'<,'>Rewrite<CR>",
        mode = { "n" },
        desc = "AI: Rewrite current line",
      },
      {
        "<leader>ae",
        ":'<,'>Rewrite<CR>",
        mode = { "v" },
        desc = "AI: Rewrite selection",
      },
      -- Hazard check: review selected code for potential issues.
      {
        "<leader>ac",
        ":'<,'>HazardCheck<CR>",
        mode = { "v" },
        desc = "AI: Check for hazards/issues",
      },
      {
        "<leader>ac",
        "V:'<,'>HazardCheck<CR>",
        mode = { "n" },
        desc = "AI: Check current line for hazards",
      },
      -- Explain: quick explanation of selected code.
      {
        "<leader>ax",
        ":'<,'>Explain<CR>",
        mode = { "v" },
        desc = "AI: Explain selection",
      },
      -- Abort: stop ongoing AI generation.
      {
        "<leader>a<c-c>",
        "<cmd>GpStop<CR>",
        mode = { "n", "v" },
        desc = "AI: Stop generation",
      },
    },
    opts = {
      cmd_prefix = "",
      providers = {
        deepseek_internal = {
          disable = false,
          endpoint = os.getenv("DEEPSEEK_INTERNAL_ENDPOINT"),
          secret = os.getenv("DEEPSEEK_INTERNAL_API_KEY"),
        }
      },
      agents = {
        {
          provider = "deepseek_internal",
          name = "inline",
          chat = false,
          system_prompt = [[
You are a professional programmer. You are going to fix the code snipppet provided possibly following the instruction in comment. The provided code are often one of these following cases:
1. Sometimes two cases (two structs, two objects, etc) given, one correct example and a bad case that needs to be fixed. Distinguish which is the correct one from your common sense, observe the example very carefully and fix the bad case.
2. Sometimes pseudo code mixed with correct code given. Findout the mocked up part, and implement the whole functionality expressed. The mocked part are ususally unknown functions with long names with underlines like `__trim_string_in_the_end__(somestring)`. You need only to identify ONE mocked up part and implement its functionality each time.
3. Sometimes there are obvious grammar error or logic hazard. Only if any fix instructions given in comment or none of conditions above applies, fix them directly. If you are performing task above, just leave warning in comment about the hazard you found. e.g. For python: # WARNING: (from AI) possible null ptr visit.
Under any condition, You should ALWAYS provide and ONLY provide code that could be replaced AS-IS of the provided part. If you are instructed to fix some certain part, you should give the full code that matches the full code snippet give, but not give only the fixed part.
Under any condition, You should NOT give ANY wasted text except code. If anything vital related to the code to suggest, leave them very briefly in comment.
          ]],
          model = {
            model = "cloudsway-claude-opus-4.5",
          }
        },
        {
          -- Lightweight reviewer agent for hazard check.
          provider = "deepseek_internal",
          name = "reviewer",
          chat = false,
          system_prompt = [[
You are a code reviewer. Analyze the given code for:
1. Potential bugs, null pointer dereferences, race conditions.
2. Resource leaks (file handles, memory, connections).
3. Security vulnerabilities (injection, overflow, etc).
4. Logic errors or edge cases not handled.

Add brief WARNING comments inline at the problematic lines.
Format: # WARNING: (AI) <description> (for Python) or // WARNING: (AI) <description> (for C/Go/Rust/JS).
Keep the original code intact. ONLY add warning comments. Do not modify the code itself.
Output the code with warnings as-is replacement.
          ]],
          model = {
            model = "cloudsway-claude-opus-4.5",
          }
        },
      },
      whisper = {
        disable = true,
      },
      image = {
        disable = true,
      },
      hooks = {
        -- Rewrite: implements pseudocode or fixes based on comments.
        Rewrite = function(gp, params)
          local template = "Having following from {{filename}}:\n\n"
              .. "```{{filetype}}\n{{selection}}\n```\n\n"
              .. "Please rewrite this according to the contained instructions."
              .. "\n\nRespond exclusively with the snippet that should replace the selection above."

          local agent = gp.get_command_agent("inline")
          gp.logger.info("Implementing selection with agent: " .. agent.name)

          gp.Prompt(
            params,
            gp.Target.rewrite,
            agent,
            template,
            nil,
            nil
          )
        end,

        -- HazardCheck: review code and add warning comments.
        HazardCheck = function(gp, params)
          local template = "Review this {{filetype}} code from {{filename}} for potential hazards:\n\n"
              .. "```{{filetype}}\n{{selection}}\n```\n\n"
              .. "Add inline WARNING comments at problematic lines. Keep all original code intact."
              .. "\n\nRespond exclusively with the code (with added warnings) that should replace the selection above."

          local agent = gp.get_command_agent("reviewer")
          gp.logger.info("Hazard checking with agent: " .. agent.name)

          gp.Prompt(
            params,
            gp.Target.rewrite,
            agent,
            template,
            nil,
            nil
          )
        end,

        -- Explain: explain code in a popup (does not modify).
        Explain = function(gp, params)
          local template = "Explain this {{filetype}} code briefly and clearly:\n\n"
              .. "```{{filetype}}\n{{selection}}\n```\n\n"
              .. "Focus on: what it does, key design decisions, and any non-obvious behavior."
              .. " Keep explanation concise (max 10 lines)."

          local agent = gp.get_command_agent("inline")
          gp.logger.info("Explaining selection with agent: " .. agent.name)

          gp.Prompt(
            params,
            gp.Target.popup,
            agent,
            template,
            nil,
            nil
          )
        end,
      }
    }
  },

  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false, -- lazy loading avante does not work...
    -- commit = "e98fa46", -- set this if you want to always pull the latest change
    enabled = true,
    keys = {
      {
        "<leader>aa",
        "<cmd>AvanteChat<CR>",
        mode = { "n" },
        -- mode = { "n", "i" }, -- it could not be insert mode. It's causing space being very slow.
        desc = "Start avante Chat",
      },
      -- { -- Now migerate inline completion to another plugin.
      --   "<leader>ae",
      --   "V<cmd>AvanteEdit<CR>",
      --   mode = { "n" },
      --   desc = "Start code completion.",
      -- },
      {
        "<leader>ah",
        "<cmd>AvanteHistory<CR>",
        mode = { "n" },
        desc = "Avante History",
      },
      {
        "<leader>am",
        "<cmd>AvanteModels<CR>",
        mode = { "n" },
        desc = "Avante Models",
      },
    },
    opts = {
      debug = false,
      mode = "legacy",
      system_prompt = "",
      custom_tools = {},
      ---@alias Provider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | string
      provider = "deepseek_internal_claude_opus", -- Recommend using Claude
      auto_suggestions_provider = "deepseek_internal_claude_haiku", -- Since auto-suggestions are a high-frequency operation and therefore expensive, it is recommended to specify an inexpensive provider or even a free provider: copilot
      providers = {
        ollama = {
          -- works well but way too slow...
          model = "openrouter_claude_haiku",
        },
        -- Weak support for local llms like ollama. But it's unnecessary for now.
        -- They are just too weak to do anything.
        ["4omini"] = {
          __inherited_from = "openai",
          api_key_name = "OPENAI_API_KEY",
          model = "gpt-4o-mini",
        },
        deepseek_internal_claude_haiku = {
          __inherited_from = "openai",
          endpoint = "https://proxy.high-five-ai.xyz:8443/v1",
          api_key_name = "DEEPSEEK_INTERNAL_API_KEY",
          model = "cloudsway-claude-haiku-4.5-cache",
          max_tokens = 10240,
          timeout = 30000,
          disable_tools = true,
        },
        deepseek_internal_claude_opus = {
          __inherited_from = "openai",
          endpoint = "https://proxy.high-five-ai.xyz:8443/v1",
          api_key_name = "DEEPSEEK_INTERNAL_API_KEY",
          model = "cloudsway-claude-opus-4.5",
          max_tokens = 10240,
          timeout = 30000,
          disable_tools = true,
        },
        openrouter_claude_opus = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "anthropic/claude-opus-4.5",
          max_tokens = 10240,
          timeout = 30000,
          disable_tools = false,
        },
        openrouter_code_completer = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "mistralai/codestral-2508",
          -- model = "qwen/qwen3-coder-flash",
          max_tokens = 102400,
          disable_tools = false,
        },
        deepseek = {
          __inherited_from = "openai",
          endpoint = "https://api.deepseek.com/",
          api_key_name = "DEEPSEEK_API_KEY",
          model = "deepseek-chat",
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
          close = { "q" },
          close_from_input = { normal = "q" },
        },
        full_view_ask = false,
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
          current = "DiffDelete",
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
