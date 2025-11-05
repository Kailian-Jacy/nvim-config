
-- AI completions.
return {
  (
    -- Detect and decide to use which version of copilot.
    -- Tencent Gongfeng > Github copilot.
    function()
      -- Copilot: detect to choose if to use local plugin.
      local copilot_dir = vim.fn.stdpath("config") .. "/pack/gongfeng/start/vim"
      local copilot = {}
      if vim.fn.isdirectory(copilot_dir) == 1 then
        copilot = {
          "copilot.vim",
          dir = copilot_dir,
          enabled = vim.g.modules.copilot and vim.g.modules.copilot.enabled,
        }
      else
        copilot = {
          "github/copilot.vim",
          enabled = vim.g.modules.copilot and vim.g.modules.copilot.enabled,
        }
      end
      return copilot
    end
  )(),
  {
    "robitx/gp.nvim",
    lazy = false,
    keys = {
      {
        "<leader>ae",
        "V:'<,'>Rewrite<CR>",
        mode = { "n" },
        desc = "Rewrite unfinished code.",
      },
      {
        "<leader>ae",
        ":'<,'>Rewrite<CR>",
        mode = { "v" },
        desc = "Rewrite unfinished code.",
      },
    },
    opts = {
      cmd_prefix = "",
      providers = {
        openrouter = {
          disable = false,
          endpoint = "https://openrouter.ai/api/v1/chat/completions",
          secret = os.getenv("OPENROUTER_API_KEY")
          -- secret = (function()
          --   local api_key = os.getenv("OPENROUTER_API_KEY")
          --   if not api_key then
          --     vim.notify("no openrouter api key found.", vim.log.levels.INFO)
          --     return ""
          --   end
          --   return api_key
          -- end)(),
        }
      },
      agents = {
        {
          provider = "openrouter",
          name = "inline",
          chat = false,
          system_prompt =
          "You are a professional programmer. You are going to fix the code snippet provided, possibly following the requirements in comment, pseudocode (those_function_with_long_descriptive_names are usually mocked to express logic, which should be replaced with actual code.) or obviously unfinished code part. You should ALWAYS provide and ONLY provide code that could be replaced AS-IS of the selected part. \nDo not add ANY other wasted text except code, including explanation, warning or any other requests. If there are possible error or anything fatal to the task you want to indicate, please put them in the comment.",
          model = {
            model = "mistralai/codestral-2508",
          }
        }
      },
      whisper = {
        disable = true,
      },
      image = {
        disable = true,
      },
      hooks = {
        -- GpImplement rewrites the provided selection/range based on comments in it
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
            nil, -- command will run directly without any prompting for user input
            nil -- no predefined instructions (e.g. speech-to-text from Whisper)
          )
        end,
      }
    }
  },
  {
    "tzachar/cmp-tabnine",
    -- there is some problem with tabnine installation. Just
    -- go to the tabnine path and run the install.sh
    build = "./install.sh",
    dependencies = "hrsh7th/nvim-cmp",
  },
  {
    "ravitemer/mcphub.nvim",
    enabled = false, -- Complains about version.
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    build = "npm install -g mcp-hub@latest", -- Installs `mcp-hub` node binary globally
    config = function()
      local mcphub = require("mcphub")
      mcphub.setup({
        auto_approve = true,
      })
      if (vim.g.modules.rust and vim.g.modules.rust.enabled) and vim.fn.executable("rustc") then
        mcphub.add_server("rust-playground")
        local cache_dir = vim.fn.stdpath("cache")
        if #cache_dir == 0 then
          vim.notify("std path cache returns empty.")
          return
        end
        cache_dir = cache_dir .. "/rust_playground"
        if vim.fn.isdirectory(cache_dir) == 0 then
          local ok = vim.fn.mkdir(cache_dir, "p")
          if ok == 0 then
            return vim.notify("Failed to create cache directory: " .. cache_dir, vim.log.levels.ERROR)
          end
        end

        mcphub.add_tool("rust-playground", {
          name = "run_rust_code",
          description = "run a rust code for validation, you should not execute heavy work inside it. You can update your code from result or compilation error.",
          inputSchema = {
            type = "object",
            properties = {
              name = {
                type = "string",
                description = "underline_connected_func_name_test that points the function you are testing, adding _test postfix. Should be a valid filename without extension.",
                examples = {
                  "bpe_algorithm_test",
                },
              },
              compile_only = {
                type = "boolean",
                description = "set to true to skip running.",
              },
              code = {
                type = "string",
                description = "code that wants to be run. Should be full code starting from main.",
                examples = {
                  'fn main() { println!("Hello, world!"); }',
                },
              },
            },
            required = { "name", "code" },
          },
          handler = function(req, res)
            local time_stamp = os.time()
            if not time_stamp then
              return res:error("Failed to generate timestamp")
            end
            local file_abs = cache_dir .. "/" .. req.params.name .. "_" .. time_stamp .. ".rs"

            local file = io.open(file_abs, "w")
            if not file then
              return res:error("Failed to create file: " .. file_abs)
            end
            file:write(req.params.code)
            file:close()

            -- Get output binary path by removing .rs extension
            local binary_path = cache_dir .. "/" .. vim.fn.fnamemodify(file_abs, ":t:r")

            -- Compile with output in same directory
            local output = vim.fn.system({ "rustc", file_abs, "-o", binary_path })
            local compilation_failed = vim.v.shell_error ~= 0

            if compilation_failed then
              return res:error("Compilation failed:\n" .. output)
            end

            local ret = res:text("Compilation succeeded.")

            if req.params.compile_only then
              -- Clean up binary if compile-only
              os.remove(binary_path)
              return ret
            end

            -- Execute the compiled binary with explicit path
            local exec_output = vim.fn.system(binary_path)
            local exec_failed = vim.v.shell_error ~= 0

            -- Clean up binary after execution
            os.remove(binary_path)

            if exec_failed then
              return res:error("Execution failed:\n" .. exec_output)
            end

            return ret:text("\nOutput:\n"):text(exec_output):send()
          end,
        })
      end
    end,
  },
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false, -- lazy loading avante does not work...
    -- commit = "e98fa46", -- set this if you want to always pull the latest change
    enabled = false,
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
      -- system_prompt as function ensures LLM always has latest MCP server state
      -- This is evaluated for every message, even in existing chats
      system_prompt = function()
        local success, module = pcall(require, "mcphub")
        if not success then
          return ""
        end
        local hub = module.get_hub_instance()
        return hub and hub:get_active_servers_prompt() or ""
      end,
      -- Using function prevents requiring mcphub before it's loaded
      custom_tools = function()
        local ret = {}
        local success, module = pcall(require, "mcphub.extensions.avante")
        if success then
          vim.tbl_extend("error", ret, {
            module.mcp_tool(),
          })
        end
        return ret
      end,
      ---@alias Provider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | string
      provider = "openrouter_code_completer", -- Recommend using Claude
      -- auto_suggestions_provider = "4o", -- Since auto-suggestions are a high-frequency operation and therefore expensive, it is recommended to specify an inexpensive provider or even a free provider: copilot
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
        openrouter_claude_haiku = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "anthropic/claude-haiku-4.5",
          max_tokens = 10240,
          timeout = 30000,
          disable_tools = false,
        },
        openrouter_claude_sonnet = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "anthropic/claude-sonnet-4.5",
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
      "ravitemer/mcphub.nvim",
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
