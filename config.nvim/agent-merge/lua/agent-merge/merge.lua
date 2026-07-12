-- agent-merge.merge — 3-way merge of line lists via `git merge-file`.
--
-- git merge-file diffs base->mine and base->theirs and combines them: cleanly
-- when the two edits don't overlap, otherwise emitting standard conflict
-- markers. It is always available wherever git is, and needs no repository.

local M = {}

-- Conflict-marker labels: <<<<<<< labels[1] / ======= / >>>>>>> labels[3].
M.labels = { "LOCAL (yours)", "BASE", "REMOTE (agent)" }

local function tmp(lines)
  local f = vim.fn.tempname()
  vim.fn.writefile(lines or {}, f)
  return f
end

--- @param mine string[]    your version (buffer)
--- @param base string[]    common ancestor
--- @param theirs string[]  agent's version (disk)
--- @return string[] merged     merged lines (with conflict markers on conflict)
--- @return integer conflicts   0 = clean, >0 = conflict count, -1 = error
function M.three_way(mine, base, theirs)
  local fm, fb, ft = tmp(mine), tmp(base), tmp(theirs)
  local res = vim
    .system({
      "git", "merge-file", "-p",
      "-L", M.labels[1], "-L", M.labels[2], "-L", M.labels[3],
      fm, fb, ft,
    }, { text = true })
    :wait()
  vim.fn.delete(fm)
  vim.fn.delete(fb)
  vim.fn.delete(ft)

  local merged = vim.split(res.stdout or "", "\n", { plain = true })
  -- writefile-style output ends in a newline -> drop the trailing empty line.
  if #merged > 0 and merged[#merged] == "" then
    table.remove(merged)
  end
  return merged, (res.code < 0 and -1 or res.code)
end

return M
