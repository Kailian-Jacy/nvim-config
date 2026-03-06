-- nvim-runner/plugin/nvim-runner.lua
-- Auto-load entry point
-- Plugin is lazy-loaded: setup() must be called by user

-- Guard against double-loading
if vim.g.loaded_nvim_runner then
  return
end
vim.g.loaded_nvim_runner = true
