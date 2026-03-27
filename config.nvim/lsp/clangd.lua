-- Clangd (C/C++) Language Server configuration
-- Only activated when cpp module is enabled (see options.lua)
local cpu_cores = vim.g._resource_cpu_cores or 4

return {
  cmd = {
    'clangd',
    '--offset-encoding=utf-16',
    '--background-index',
    '-j=' .. math.max(cpu_cores - 2, 2),
  },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
  root_markers = { '.clangd', '.clang-tidy', '.clang-format', 'compile_commands.json', 'compile_flags.txt', 'configure.ac', '.git' },
}
