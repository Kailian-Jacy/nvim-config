-- agent-merge — reconcile concurrent edits between you and an external agent
-- that rewrites the same file on disk.
--
-- This step wires the `watch` primitive to file buffers and reacts
-- non-invasively: a clean buffer silently reloads the agent's version, a
-- modified buffer just gets a heads-up. The real 3-way merge-on-save lands in
-- the next step, layered on top of this same wiring.

local watch = require("agent-merge.watch")

local M = {}
-- Re-export the core primitives.
M.watch = watch.watch
M.unwatch = watch.unwatch

M.config = {
  poll_ms = watch.DEFAULT_POLL_MS,
  notify = true,
}

local handles = {} ---@type table<integer, table> -- bufnr -> watch handle

local function notify(msg, level)
  if M.config.notify then
    vim.notify(msg, level or vim.log.levels.INFO, { title = "agent-merge" })
  end
end

local function watchable(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return vim.bo[buf].buftype == ""
    and name ~= ""
    and not name:match("^%w+://")
    and vim.fn.filereadable(name) == 1
end

local function detach(buf)
  if handles[buf] then
    watch.unwatch(handles[buf])
    handles[buf] = nil
  end
end

local function attach(buf)
  detach(buf)
  if not watchable(buf) then return end
  handles[buf] = watch.watch(vim.api.nvim_buf_get_name(buf), function()
    if vim.api.nvim_buf_is_valid(buf) then
      -- Let Neovim compare buffer vs. disk; FileChangedShell decides what to do.
      vim.api.nvim_buf_call(buf, function() vim.cmd("silent! checktime") end)
    end
  end, { poll_ms = M.config.poll_ms })
end

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
  vim.o.autoread = true

  local grp = vim.api.nvim_create_augroup("AgentMerge", { clear = true })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufFilePost", "BufWritePost" }, {
    group = grp,
    callback = function(a) attach(a.buf) end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = grp,
    callback = function(a) detach(a.buf) end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = grp,
    callback = function()
      for buf in pairs(handles) do detach(buf) end
    end,
  })

  -- Non-invasive reaction (real merge comes next step).
  vim.api.nvim_create_autocmd("FileChangedShell", {
    group = grp,
    callback = function(a)
      local tail = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(a.buf), ":t")
      if vim.v.fcs_reason == "deleted" then
        vim.v.fcs_choice = "" -- keep our buffer
        notify("File deleted on disk: " .. tail, vim.log.levels.WARN)
      elseif vim.bo[a.buf].modified then
        vim.v.fcs_choice = "" -- both changed; don't disturb, defer to merge
        notify("Agent edited " .. tail .. " on disk (buffer also modified).")
      else
        vim.v.fcs_choice = "reload" -- only disk changed; adopt it
      end
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do attach(buf) end
end

return M
