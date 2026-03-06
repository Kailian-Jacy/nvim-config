-- nvim-runner/lua/nvim-runner/config.lua
-- Default configuration for nvim-runner

local M = {}

---@class NvimRunnerConfig
---@field runners table<string, RunnerDefinition>
---@field timeout number Default timeout in milliseconds
---@field insert_result boolean Whether to insert result into buffer
---@field keymaps table|false Keymap configuration, false to disable
M.defaults = {
  runners = {
    python = {
      runner = function()
        -- Use python: venv-selector > python3 > python
        local candidates = {}

        -- Try venv-selector if available
        local ok, venv = pcall(require, "venv-selector")
        if ok then
          local venv_python = venv.python()
          if venv_python and #venv_python > 0 then
            table.insert(candidates, venv_python)
          end
        end

        table.insert(candidates, "python3")
        table.insert(candidates, "python")

        for _, candidate in ipairs(candidates) do
          if vim.fn.executable(candidate) ~= 0 then
            return candidate
          end
        end

        vim.notify("no usable python interpreter.", vim.log.levels.ERROR)
        return ""
      end,
      template = "echo -e | ${runner} <<EOF\n${text}\nEOF",
      timeout = 3000, -- ms
    },
    nu = {
      runner = "nu",
      template = "COMMANDS=$(cat<<EOF\n${text}\nEOF\n);${runner} --commands $COMMANDS --no-newline",
      timeout = 5000, -- ms
    },
    lua = {
      runner = "this_neovim",
      template = "${text}",
    },
    sh = {
      runner = "zsh",
      template = "${text}",
    },
  },
  timeout = 3000, -- default timeout in ms
  insert_result = true, -- insert result at cursor position
  keymaps = {
    run = { "<c-s-cr>", "<d-s-cr>" }, -- key(s) to trigger RunScript
  },
}

---@type NvimRunnerConfig
M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
