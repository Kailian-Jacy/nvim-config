-- This is a lua file that contains local settings
-- It will not be synchronized between git repos.

M = {}

-- Temporary workaround for tencent gbk encodings.
vim.api.nvim_create_autocmd({
  "BufReadPost",
}, {
  command = ":e ++enc=gb2312",
})

vim.g.clipboard = nil
vim.g.do_not_format_all = true

return M
