-- dsh.nvim — the DeepSeek Harness ⇄ neovim bridge.
--
-- Features are namespaced submodules; `walkthrough` is the first. Everything is
-- designed to be driven over the RPC socket by an agent as well as by keys.
local M = {}

M.version = "0.1.0"

--- @param opts table|nil { walkthrough = { ... } }
function M.setup(opts)
  opts = opts or {}
  local out = { "dsh.nvim " .. M.version }
  out[#out + 1] = require("dsh.walkthrough").setup(opts.walkthrough)
  return table.concat(out, " | ")
end

--- Lazily expose submodules: require("dsh").walkthrough.next()
setmetatable(M, {
  __index = function(_, key)
    local ok, mod = pcall(require, "dsh." .. key)
    if ok then return mod end
    return nil
  end,
})

return M
