-- Defaults for the walkthrough engine.
local M = {}

M.defaults = {
  -- Panel geometry. 58 is the narrowest width at which a code card (left inset
  -- + inner padding + right gutter) still fits a 50-column code line.
  panel_width = 58,

  -- Code card geometry, in panel columns.
  --   left = where the card background starts; keep equal to prose indent
  --   text = where code text starts; the difference is inner padding
  card = { left = 4, text = 6 },

  -- Progressive-disclosure layers, outermost first. Detail is ALWAYS scoped to
  -- the focused step; there is deliberately no "expand everything" layer.
  layers = { "OUTLINE", "BRIEF" },

  -- Global keys, saved and restored on close().
  keys = {
    next = "<leader>qj",
    prev = "<leader>qk",
    toggle_panel = "<leader>qq",
    layer = "<leader>qi",
  },

  own_tab = true, -- open in a dedicated tabpage
  signs = true, -- gutter marker on annotated lines
  no_dim = true, -- exempt our windows from vimade-style inactive fading
  echo = false, -- per-jump echo; off because it surfaces as a noice popup

  -- Lock the annotated source buffers 'nomodifiable' while the walkthrough owns
  -- them, restoring the previous value on close.
  --
  -- This is not cosmetic. A walkthrough parks the cursor in a real, writable
  -- source buffer belonging to someone else's installed plugin. A single stray
  -- keystroke edits it, and with an autosave plugin active that edit is written
  -- to disk and 'modified' goes straight back to false -- so it is silent. Read
  -- only is the correct default for a window whose whole purpose is reading.
  readonly_source = true,
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

--- Widest code line that fits a card without truncation.
--- panel_width - 1 (last usable col) - 1 (right gutter) - card.text
function M.max_code_width(o)
  o = o or M.options
  return o.panel_width - 2 - o.card.text
end

--- Widest prose line inside a detail section.
function M.max_prose_width(o)
  o = o or M.options
  return o.panel_width - 6
end

return M
