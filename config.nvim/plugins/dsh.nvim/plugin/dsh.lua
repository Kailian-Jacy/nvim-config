-- User commands for dsh.nvim. Thin wrappers over the Lua API so a human can
-- drive the same surface the agent drives over the socket.
if vim.g.loaded_dsh_nvim then return end
vim.g.loaded_dsh_nvim = true

local function wt() return require("dsh.walkthrough") end
local function notify(msg)
  vim.notify(msg, msg:find("^ERROR") or msg:find("^REFUSED") and vim.log.levels.ERROR
    or vim.log.levels.INFO, { title = "walkthrough" })
end

vim.api.nvim_create_user_command("WalkthroughOpen", function(a)
  notify(wt().open(vim.fn.expand(a.args), { force = a.bang }))
end, { nargs = 1, bang = true, complete = "file", desc = "open a walkthrough deck (JSON)" })

vim.api.nvim_create_user_command("WalkthroughValidate", function(a)
  notify(wt().validate(vim.fn.expand(a.args), true))
end, { nargs = 1, complete = "file", desc = "validate a walkthrough deck without opening it" })

vim.api.nvim_create_user_command("WalkthroughClose", function()
  notify(wt().close())
end, { desc = "close the walkthrough and restore keymaps" })

vim.api.nvim_create_user_command("WalkthroughReload", function()
  notify(wt().reload())
end, { desc = "re-read the current deck file" })

vim.api.nvim_create_user_command("Walkthrough", function(a)
  if a.args ~= "" then wt().goto_step(tonumber(a.args)) else notify(wt().status()) end
end, { nargs = "?", desc = "jump to a step, or report status" })

vim.api.nvim_create_user_command("WalkthroughLayer", function(a)
  wt().layer(a.args ~= "" and tonumber(a.args) or nil)
end, { nargs = "?", desc = "cycle or set the disclosure layer" })
