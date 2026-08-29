-- Inline code annotation, built entirely from extmark decorations.
--
-- Nothing here writes to a file or sets 'modified': virt_lines, virt_text and
-- sign_text are display-only buffer metadata. `clear` reverts to pristine.
local Config = require("dsh.walkthrough.config")
local Deck = require("dsh.walkthrough.deck")
local Hl = require("dsh.walkthrough.hl")
local Text = require("dsh.walkthrough.text")

local M = {}
M.ns = vim.api.nvim_create_namespace("dsh_walkthrough_code")

function M.clear(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_clear_namespace, buf, M.ns, 0, -1)
  end
end

--- Decorate `buf` for one step. Returns a list of unresolved anchor patterns.
function M.apply(buf, st, win)
  M.clear(buf)
  local o = Config.options
  local last = vim.api.nvim_buf_line_count(buf)
  local lo = math.max(1, st.range[1])
  local hi = math.min(st.range[2], last)
  local unresolved = {}

  -- 1. region tint over the lines this step is about
  for l = lo, hi do
    pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, l - 1, 0,
      { line_hl_group = "DshWalkRegion" })
  end

  -- textoff excludes sign/number/fold columns, so padding lines up with where
  -- virtual text actually starts.
  local wi = win and vim.fn.getwininfo(win)[1] or nil
  local textw = wi and (wi.width - wi.textoff)
    or (win and vim.api.nvim_win_get_width(win)) or 80
  textw = math.max(30, textw)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local signed = {}

  for _, a in ipairs(st.ann or {}) do
    local l = Deck.resolve(lines, a.pat, lo, hi)
    if not l then
      unresolved[#unresolved + 1] = a.pat
    elseif a.kind == "eol" then
      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, l - 1, 0, {
        virt_text = { { "  ◂ " .. a.text, "DshWalkPtr" } },
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    else
      local tinted = Hl.tint_bg ~= nil and l >= lo and l <= hi
      local g_rule = tinted and "DshWalkRuleT" or "DshWalkRule"
      local g_note = tinted and "DshWalkNoteT" or "DshWalkNote"
      local indent = (lines[l] or ""):match("^(%s*)")
      local width = math.max(30, textw - #indent - 4)
      -- pad each virtual line to the full text width, or the region background
      -- stops mid-line and the block punches a hole in the tint
      local function row(chunks)
        if tinted then
          local used = 0
          for _, c in ipairs(chunks) do used = used + vim.fn.strdisplaywidth(c[1]) end
          if used < textw then
            chunks[#chunks + 1] = { string.rep(" ", textw - used), "DshWalkRegion" }
          end
        end
        return chunks
      end
      local vl = { row({ { indent .. "╭─", g_rule } }) }
      for _, t in ipairs(Text.wrap(a.text, width)) do
        vl[#vl + 1] = row({ { indent .. "│ ", g_rule }, { t, g_note } })
      end
      vl[#vl + 1] = row({ { indent .. "╰─", g_rule } })
      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, l - 1, 0,
        { virt_lines = vl, virt_lines_above = true })
    end
    if l and o.signs and not signed[l] then
      signed[l] = true
      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, l - 1, 0,
        { sign_text = "▌", sign_hl_group = "DshWalkSign" })
    end
  end

  return unresolved
end

return M
