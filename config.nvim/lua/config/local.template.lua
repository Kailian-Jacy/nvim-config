-- This is a lua file that contains local settings.
-- It will not be synchronized between git repos.
-- Rename this file to local.lua to make it take effect.

M = {}

local modules = {}

M.before_all = function()
  -- Status bar sign.
  -- vim.g._status_bar_system_icon = "?"

  -- -- Set `vim.g.modules` customization with `modules`
  -- modules.svn = false
  -- -- Be sure to write them back
  -- vim.g.modules = modules

  -- Tab name indicator. Name will be marked if any matching.
  -- The former, the priorer.
  -- vim.g.tab_path_mark = { ["Branch_OB_Publish"] = "P", ["Branch_GServers_%d+"] = "G", ["Branch_NServers_%d+"] = "N" }
end
M.after_options = function()
  -- Temporary workaround for tencent gbk encodings.
  -- vim.g.clipboard = nil
  -- vim.g.do_not_format_all = true
  -- vim.cmd[[ set fileencodings=ucs-bom,gb2312,utf-8,latin1,euc-cn ]]
end

M.before_plugins_load = function()
  -- @An example to add dap configuration.
  -- -- Add more local dap configs.
  -- local dap = require("dap")
  -- local core_config =
  --   {
  --     name = "Debug last Coredump in Trunk",
  --     type = "codelldb",
  --     request = "attach",
  --     targetCreateCommands = function()
  --     return coroutine.create(function(dap_run_co)
  --       local items = { "scene", "world", "briefcache", "abort" }
  --       vim.ui.select(items, { prompt = "Which directory to search for core files?" }, function(choice)
  --         if choice == nil or choice == "abort" then
  --           coroutine.resume(dap_run_co, dap.ABORT)
  --           return
  --         end
  --
  --         -- Search the path dir to find core files
  --         local bin_path = "/data/home/zianxu/master/release/qsshome/" .. choice .. "/bin/"
  --         local core_files = vim.fn.glob(bin_path .. "core.*", false, true)
  --         if #core_files == 0 then
  --           vim.notify("No core files found in " .. bin_path, vim.log.levels.ERROR)
  --           coroutine.resume(dap_run_co, dap.ABORT)
  --           return
  --         end
  --
  --         -- Sort core files by modification time to get the latest one
  --         table.sort(core_files, function(a, b)
  --           local stat_a = vim.loop.fs_stat(a)
  --           local stat_b = vim.loop.fs_stat(b)
  --           return stat_a.mtime.sec > stat_b.mtime.sec
  --         end)
  --
  --         -- Use the latest (most recently modified) core file
  --         local latest_core = core_files[1]
  --         local core_name = vim.fn.fnamemodify(latest_core, ":t")
  --         local stat = vim.loop.fs_stat(latest_core)
  --         local creation_time = os.date("%Y-%m-%d %H:%M:%S", stat.mtime.sec)
  --
  --         vim.notify("Using latest core file: " .. core_name .. " (created: " .. creation_time .. ")", vim.log.levels.INFO)
  --
  --         local target_cmd = "target create -c " .. latest_core
  --         coroutine.resume(dap_run_co, { target_cmd })
  --       end)
  --     end)
  --     end,
  --     processCreateCommands = {}
  --   }
  -- if not dap.configurations.cpp then
  --   dap.configurations.cpp = {}
  -- end
  -- dap.configurations.cpp[#dap.configurations.cpp + 1] = core_config
end
M.after_plugins_load = function()
  -- Formatter example. More: https://github.com/stevearc/conform.nvim?tab=readme-ov-file
  -- require("conform").formatters.shfmt = {
  --   append_args = { "-i", "2" },
  --   -- The base args are { "-filename", "$FILENAME" } so the final args will be
  --   -- { "-filename", "$FILENAME", "-i", "2" }
  -- }
end

M.before_autocmds = function() end
M.after_autocmds = function() end

M.before_keymaps = function() end
M.after_all = function() end

return M
