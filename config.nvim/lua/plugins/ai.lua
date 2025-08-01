-- AI completions.
return {
  -- from ai store.
  {
    "github/copilot.vim",
    enabled = vim.g.modules.copilot and vim.g.modules.copilot.enabled,
  },
  {
    "tzachar/cmp-tabnine",
    -- there is some problem with tabnine installation. Just
    -- go to the tabnine path and run the install.sh
    build = "./install.sh",
    dependencies = "hrsh7th/nvim-cmp",
  },
  -- tencent copilot (gongfeng).
  --[[{
    "copilot.vim",
  },]]
  {
    "ravitemer/mcphub.nvim",
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
        local hub = require("mcphub").get_hub_instance()
        return hub and hub:get_active_servers_prompt() or ""
      end,
      -- Using function prevents requiring mcphub before it's loaded
      custom_tools = function()
        return {
          require("mcphub.extensions.avante").mcp_tool(),
        }
      end,
      ---@alias Provider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | string
      provider = "openrouter_claude_4", -- Recommend using Claude
      -- auto_suggestions_provider = "4o", -- Since auto-suggestions are a high-frequency operation and therefore expensive, it is recommended to specify an inexpensive provider or even a free provider: copilot
      providers = {
        ollama = {
          -- works well but way too slow...
          model = "devstral:latest",
        },
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
          model = "google/gemini-2.5-pro-preview",
          max_tokens = 102400,
          disable_tools = true,
        },
        openrouter_gemini_flash = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "google/gemini-2.5-flash-preview-05-20",
          max_tokens = 10240,
          disable_tools = true,
        },
        openrouter_claude_4 = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "anthropic/claude-sonnet-4",
          max_tokens = 10240,
          timeout = 30000,
          disable_tools = false,
        },
        openrouter_claude_3_5 = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = "anthropic/claude-3.5-sonnet",
          max_tokens = 10240,
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
