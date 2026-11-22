-- Subcommit pane: a quiet list of every subcommit docked under the CodeDiff explorer
-- of the [track] tab. Add-on only: finds the explorer by buffer filetype, follows it
-- through WinNew/WinClosed, borrows codediff's own highlights, never patches codediff.
local M = {}
local NS = vim.api.nvim_create_namespace("agent_track_pane")
local BADGE = { approved = "✓", rejected = "✗", stale = "~", pending = "·" }
local HL = { approved = "AgentTrackApproved", rejected = "AgentTrackRejected", stale = "AgentTrackStale", pending = "AgentTrackPending" }
local DEF_HL = { AgentTrackPaneHeader = "CodeDiffExplorerTreeGroup", AgentTrackPaneCurrent = "CodeDiffExplorerSelected", AgentTrackPaneDim = "Comment" }
local WO = { number = false, relativenumber = false, cursorline = true, wrap = false, list = false, spell = false, signcolumn = "no", foldcolumn = "0", statuscolumn = "", winfixwidth = true, winfixheight = true }
local P, group = {}, nil -- P[tabpage] = { win, buf, session, root, sha, items, anchored, h, user_closed, closing }

local function track() return require("agent-track") end
local function opts() local ok, t = pcall(track); local r = ok and t.get_config and (t.get_config().reviewer or {}) or {}; return vim.tbl_extend("force", { enabled = true, max_height = 10 }, r.pane or {}) end
local function valid(w) return w ~= nil and vim.api.nvim_win_is_valid(w) end
local function dw(s) return vim.fn.strdisplaywidth(s) end
local function explorer_win(tab)
  for _, w in ipairs(vim.api.nvim_tabpage_is_valid(tab) and vim.api.nvim_tabpage_list_wins(tab) or {}) do
    if vim.api.nvim_win_get_config(w).relative == "" and vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "codediff-explorer" then return w end
  end
end
local function trunc(s, w)
  if w < 2 then return "" elseif dw(s) <= w then return s end
  local out, used = {}, 0
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do local c = dw(ch); if used + c > w - 1 then break end; out[#out + 1], used = ch, used + c end
  return table.concat(out) .. "…"
end

local function render(tab)
  local p = P[tab]; if not (p and p.buf and vim.api.nvim_buf_is_valid(p.buf)) then return end
  local items, width = p.items or {}, valid(p.win) and vim.api.nvim_win_get_width(p.win) or 40
  local n, cur, iw, lines, hls = { approved = 0, rejected = 0, pending = 0 }, 0, #tostring(#items), {}, {}
  for i, it in ipairs(items) do
    local k = (it.review_status == "stale" or not n[it.review_status]) and "pending" or it.review_status; n[k] = n[k] + 1
    if it.sha == p.sha then cur = i end
  end
  local function row(chunks) -- { {text, hl?}, ... } -> one line + byte-range highlights
    local s = ""
    for _, c in ipairs(chunks) do if c[2] and #c[1] > 0 then hls[#hls + 1] = { #lines, #s, #s + #c[1], c[2] } end; s = s .. c[1] end
    lines[#lines + 1] = s
  end
  local function cells(chunks) local w = 0; for _, c in ipairs(chunks) do w = w + dw(c[1]) end; return w end
  local title, stats = string.format(" Subcommits (%d)", #items), {}
  for _, k in ipairs({ "approved", "rejected", "pending" }) do if n[k] > 0 then stats[#stats + 1] = BADGE[k] .. n[k] end end
  local right = table.concat(stats, " ")
  row({ { title, "AgentTrackPaneHeader" }, { string.rep(" ", math.max(1, width - dw(title) - dw(right) - 1)) }, { right, "AgentTrackPaneDim" } })
  for _, it in ipairs(items) do -- like the explorer rows above: glyph + name on the left, status at the right edge
    local b = (it.review_status == "approved" and it.review_via == "prefix") and "✓*" or (BADGE[it.review_status] or "·")
    local l = { { " " }, { it.synced and "●" or "○", it.synced and "AgentTrackSynced" or "AgentTrackPending" }, { string.format(" %" .. iw .. "d ", it.index or 0), "AgentTrackPaneDim" } }
    if width >= 56 then l[#l + 1] = { (it.short_sha or (it.sha or ""):sub(1, 7)) .. " ", "AgentTrackPaneDim" } end
    local r = { { b, HL[it.review_status] or "AgentTrackPending" }, { " " } }
    if it.would_conflict then table.insert(r, 1, { "⚡", "AgentTrackConflict" }) end
    local subj = trunc(it.subject or "", width - cells(l) - cells(r) - 1)
    l[#l + 1] = { subj }; l[#l + 1] = { string.rep(" ", math.max(1, width - cells(l) - cells(r))) }
    row(vim.list_extend(l, r))
  end
  vim.bo[p.buf].modifiable = true; vim.api.nvim_buf_set_lines(p.buf, 0, -1, false, lines); vim.bo[p.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(p.buf, NS, 0, -1)
  for _, h in ipairs(hls) do vim.api.nvim_buf_set_extmark(p.buf, NS, h[1], h[2], { end_col = h[3], hl_group = h[4] }) end
  if cur > 0 then vim.api.nvim_buf_set_extmark(p.buf, NS, cur, 0, { line_hl_group = "AgentTrackPaneCurrent" }) end
  if not valid(p.win) then return end
  local want = math.max(2, math.min(#lines, opts().max_height)) -- only resize when the list grows/shrinks, so manual resizes stick
  if p.anchored and p.h ~= want then p.h = want; pcall(vim.api.nvim_win_set_height, p.win, want) end
  if cur > 0 and (vim.api.nvim_get_current_win() ~= p.win or p.shown_sha ~= p.sha) then pcall(vim.api.nvim_win_set_cursor, p.win, { cur + 1, 0 }) end
  p.shown_sha = p.sha
end

local function relist(p)
  local ok, res = pcall(function() return track().list(p.session, { cwd = p.root }) end)
  if not (ok and type(res) == "table" and res.ok) then return end
  local warn = {}; for _, it in ipairs(p.items or {}) do warn[it.sha] = it.would_conflict end -- ⚡ is only computed by the reviewer's full fetch
  for _, it in ipairs(res.items or {}) do if not it.synced and warn[it.sha] then it.would_conflict = true end end
  p.items = res.items or {}
end
function M.refresh(tab)
  for t, p in pairs(P) do
    if not vim.api.nvim_tabpage_is_valid(t) then P[t] = nil elseif tab == nil or t == tab then relist(p); render(t) end
  end
end

local function new_buf(tab)
  local b = vim.api.nvim_create_buf(false, true)
  for k, v in pairs({ buftype = "nofile", bufhidden = "wipe", swapfile = false, modifiable = false, filetype = "agent-track-pane" }) do vim.bo[b][k] = v end
  pcall(vim.api.nvim_buf_set_name, b, "AgentTrack Subcommits [" .. tab .. "]")
  local function act(fn) return function() local p = P[tab]; local it = p and (p.items or {})[vim.api.nvim_win_get_cursor(0)[1] - 1]; if it then fn(it, p) end end end
  local function review(status, prompt) return act(function(it, p)
    local function go(cm)
      if cm == nil then return end
      local r = track().review(it.sha, status, { comment = cm, session = p.session, cwd = p.root, async_push = true })
      if type(r) == "table" and r.ok == false then vim.notify("agent-track: " .. tostring(r.error), vim.log.levels.WARN) end
    end
    if prompt then vim.ui.input({ prompt = prompt }, go) else go("") end
  end) end
  local open = act(function(it, p) require("agent-track.reviewer").open(it.sha, { session = p.session }) end)
  local function message(it) -- p: the full message (subject, why/body, trailers, review comment) in a float
    local out = { string.format("#%d %s  %s%s", it.index or 0, it.short_sha or (it.sha or ""):sub(1, 7), it.review_status or "pending", it.would_conflict and "  ⚡ would conflict on sync" or ""), "", it.subject or "" }
    local body = vim.trim(it.body or "")
    if body ~= "" then out[#out + 1] = ""; vim.list_extend(out, vim.split(body, "\n", { plain = true })) end
    if (it.comment or "") ~= "" then vim.list_extend(out, { "", "Review: " .. it.comment }) end
    vim.lsp.util.open_floating_preview(out, "gitcommit", { border = "rounded", max_width = 100, wrap = true, focus_id = "agent_track_message" })
  end
  local maps = { ["<CR>"] = open, o = open, ["<2-LeftMouse>"] = open, p = act(message), a = review("approved"), C = review("approved", "Approve comment: "),
    x = review("rejected", "Reject reason: "), R = function() M.refresh(tab) end }
  for lhs, fn in pairs(maps) do vim.keymap.set("n", lhs, fn, { buffer = b, silent = true, nowait = true, desc = "AgentTrack pane" }) end
  return b
end

local function open_win(tab)
  local p, c = P[tab], opts()
  local ex, okc, cdc = explorer_win(tab), pcall(require, "codediff.config")
  local ecfg = (okc and type(cdc.options) == "table" and cdc.options.explorer) or {}
  local h = math.max(2, math.min(#(p.items or {}) + 1, c.max_height))
  local wc
  if ex then wc = ecfg.position == "bottom" and { split = "right", win = ex, width = c.width or 50 } or { split = "below", win = ex, height = h }
  elseif tab == vim.api.nvim_get_current_tabpage() then wc = { split = "left", win = -1, width = ecfg.width or 40 } -- no explorer: same left column
  else return end
  if not (p.buf and vim.api.nvim_buf_is_valid(p.buf)) then p.buf = new_buf(tab) end
  local ok, w = pcall(vim.api.nvim_open_win, p.buf, false, wc); if not ok then return end
  p.win, p.anchored, p.h = w, ex ~= nil, h
  for k, v in pairs(WO) do pcall(function() vim.wo[w][k] = v end) end
  if ex then for _, k in ipairs({ "winhighlight", "statuscolumn" }) do pcall(function() vim.wo[w][k] = vim.wo[ex][k] end) end end
  render(tab)
end

local function reconcile()
  for tab, p in pairs(P) do
    if not vim.api.nvim_tabpage_is_valid(tab) then P[tab] = nil
    elseif p.anchored and not p.user_closed then -- hide/show together with the explorer (`toggle_explorer`)
      local ex, shown = explorer_win(tab), valid(p.win)
      if shown and not ex then p.closing = true; pcall(vim.api.nvim_win_close, p.win, true); p.closing, p.win = false, nil
      elseif ex and not shown then open_win(tab) end
    end
  end
end
local function ensure_autocmds()
  if group then return end
  group = vim.api.nvim_create_augroup("AgentTrackPane", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", { group = group, callback = function(ev)
    local w = tonumber(ev.match)
    for _, p in pairs(P) do if p.win == w and not p.closing then p.user_closed, p.win = true, nil end end -- closed by the user: stay closed
    vim.schedule(reconcile)
  end })
  vim.api.nvim_create_autocmd({ "WinNew", "TabClosed" }, { group = group, callback = function() vim.schedule(reconcile) end })
  vim.api.nvim_create_autocmd("WinResized", { group = group, callback = function()
    for t, p in pairs(P) do if valid(p.win) and vim.tbl_contains(vim.v.event.windows or {}, p.win) then render(t) end end
  end })
  vim.api.nvim_create_autocmd("User", { group = group, pattern = { "AgentTrackUpdated", "AgentTrackReviewed", "AgentTrackSynced" }, callback = function() M.refresh() end })
end

--- Show (or update) the pane of `tab`. ctx = { session, root, sha, items }.
function M.show(tab, ctx)
  if opts().enabled == false or not (tab and vim.api.nvim_tabpage_is_valid(tab)) then return end
  for g, l in pairs(DEF_HL) do vim.api.nvim_set_hl(0, g, { link = l, default = true }) end
  ensure_autocmds(); ctx = ctx or {}
  local p = P[tab] or {}; P[tab] = p
  p.session, p.root, p.sha, p.items = ctx.session or p.session, ctx.root or p.root, ctx.sha or p.sha, ctx.items or p.items or {}
  if #p.items == 0 then return end
  if valid(p.win) then render(tab) elseif not p.user_closed then open_win(tab) end
  return p.win
end
function M.get(tab)
  local p = P[tab or vim.api.nvim_get_current_tabpage()]
  return p and { win = valid(p.win) and p.win or nil, buf = p.buf, sha = p.sha, items = p.items, anchored = p.anchored, user_closed = p.user_closed } or nil
end
return M
