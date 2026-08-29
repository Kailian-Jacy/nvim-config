-- Panel rendering: the storyline sidebar.
local Config = require("dsh.walkthrough.config")
local Text = require("dsh.walkthrough.text")

local M = {}
M.ns = vim.api.nvim_create_namespace("dsh_walkthrough_panel")

local function shortpath(path, roots)
  for _, r in ipairs(roots or {}) do
    if r.dir and path:find(r.dir, 1, true) == 1 then
      return r.label .. path:sub(#r.dir + 1)
    end
  end
  return vim.fn.fnamemodify(path, ":t")
end

--- Render the panel for session `s`. Returns line_of_step, step_of_line.
function M.render(s)
  local o = Config.options
  local PW = o.panel_width - 1
  local W = Config.max_prose_width(o)
  local CARD_L, CARD_T = o.card.left, o.card.text
  local buf, win = s.panel_buf, s.panel_win

  local lines, marks = {}, {}
  local line_of_step, step_of_line = {}, {}

  -- marks are { row0, col0, opts }: a full-line mark uses end_row + hl_eol, a
  -- ranged mark uses end_col so a code card can be inset from the margin.
  local function mark(row0, col0, group, col1, extra)
    local opts = { hl_group = group }
    if col1 then opts.end_col = col1 else opts.end_row = row0 + 1; opts.hl_eol = true end
    for k, v in pairs(extra or {}) do opts[k] = v end
    marks[#marks + 1] = { row0, col0, opts }
  end

  local function put(txt, group)
    lines[#lines + 1] = txt
    if group then mark(#lines - 1, 0, group) end
  end

  -- A code block as an inset card: its left edge aligns with the surrounding
  -- prose rather than bleeding into the panel margin, and text is syntax-
  -- accented rather than one flat colour.
  local function emit_code(code)
    for _, l in ipairs(Text.code_lines(code)) do
      local t = string.rep(" ", CARD_T) .. l
      if vim.fn.strdisplaywidth(t) > PW - 1 then t = t:sub(1, PW - 2) .. "…" end
      local w = vim.fn.strdisplaywidth(t)
      if w < PW - 1 then t = t .. string.rep(" ", PW - 1 - w) end
      lines[#lines + 1] = t
      local row = #lines - 1
      mark(row, CARD_L, "DshWalkCodeBlk", #t, { priority = 100 })
      for _, tk in ipairs(Text.tokens(l)) do
        mark(row, CARD_T + tk[1], tk[3], CARD_T + tk[2], { priority = 110 })
      end
    end
  end

  local function emit_section(blk, indent)
    if blk.h then put(indent .. "▸ " .. blk.h, "DshWalkSection") end
    if blk.t then
      for _, l in ipairs(Text.wrap(blk.t, W)) do
        put(l == "" and "" or (indent .. l), "DshWalkBody")
      end
    end
    if blk.c then emit_code(blk.c) end
    put("", nil)
  end

  local layer = o.layers[s.layer] or o.layers[1]
  local show_brief = layer ~= "OUTLINE"
  local steps = s.deck.steps

  put("  " .. s.deck.title, "DshWalkHead")
  put(("  step %d/%d   layer: %s"):format(s.idx, #steps, layer), "DshWalkDim")
  put(("  %s toggles %s"):format(o.keys.layer:gsub("<leader>", " "),
    table.concat(o.layers, " ⇄ ")), "DshWalkDim")
  if #s.unresolved > 0 then
    put(("  ! %d unresolved anchor(s)"):format(#s.unresolved), "WarningMsg")
  end
  put(string.rep("─", PW), "DshWalkRule")

  local cur_act
  for i, st in ipairs(steps) do
    if st.act and st.act ~= cur_act then
      cur_act = st.act
      put("", nil)
      put("  " .. cur_act, "DshWalkAct")
    end
    local focused = (i == s.idx)
    local head = string.format(" %s %2d  %s", focused and "▶" or " ", i, st.title)
    line_of_step[i] = #lines + 1
    put(head, focused and "DshWalkCur"
      or ((st.title:find("★", 1, true) and "DshWalkStar") or "DshWalkDim"))
    step_of_line[#lines] = i

    if show_brief then
      for _, l in ipairs(Text.wrap(st.brief, W)) do
        put("     " .. l, focused and "DshWalkBody" or "DshWalkBrief")
      end
    end

    -- Detail is ALWAYS scoped to the focused step. There is no expand-all layer.
    if focused then
      put("     " .. shortpath(st.file, s.deck.roots) .. ":" .. st.lnum, "Underlined")
      put("", nil)
      if layer == "OUTLINE" then
        for _, l in ipairs(Text.wrap(st.body, W)) do
          put(l == "" and "" or ("    " .. l), "DshWalkBody")
        end
        put("", nil)
      else
        for _, blk in ipairs(st.detail) do emit_section(blk, "    ") end
      end
      if #st.ann > 0 then
        put(("    %d inline annotations in the code →"):format(#st.ann), "DshWalkPtr")
        put("", nil)
      end
    end
  end

  put("", nil)
  put(string.rep("─", PW), "DshWalkRule")
  put(("  %s next  %s prev  %s hide"):format(
    o.keys.next:gsub("<leader>", " "), o.keys.prev:gsub("<leader>", " "),
    o.keys.toggle_panel:gsub("<leader>", " ")), "DshWalkDim")
  put("  <CR> jump   <Tab> layer   :WalkthroughClose", "DshWalkDim")

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  for _, m in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, m[1], m[2], m[3])
  end

  -- keep the focused step (and as much of its detail as fits) on screen
  local target = line_of_step[s.idx]
  if target and win and vim.api.nvim_win_is_valid(win) then
    local height = vim.api.nvim_win_get_height(win)
    local context = math.min(6, math.max(0, math.floor(height / 6)))
    local top = math.max(1, math.min(target - context, math.max(1, #lines - height + 1)))
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview({ topline = top, lnum = target, col = 0, leftcol = 0 })
    end)
  end

  return line_of_step, step_of_line
end

return M
