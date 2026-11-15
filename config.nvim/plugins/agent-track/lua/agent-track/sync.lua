local config = require("agent-track.config")
local git = require("agent-track.git")
local M = {}

local function maybe_save() if config.get().auto_save_before_sync then vim.cmd("silent! wall") end end
local function tree_of(root, rev) return rev and git.rev_parse(root, rev .. "^{tree}") or nil end
local function tree_paths(root, t1, t2)
  local r = (t1 and t2 and t1 ~= t2) and git.run(root, { "diff-tree", "-r", "-z", "--name-only", t1, t2 }, { ident = false }) or nil
  return (r and r.ok and r.stdout ~= "") and vim.split(r.stdout, "\0", { plain = true, trimempty = true }) or {}
end
local function with_tmp_index(copy_from, fn)
  local tmp = vim.fn.tempname(); pcall(vim.uv.fs_unlink, tmp)
  if copy_from and vim.uv.fs_stat(copy_from) then assert(vim.uv.fs_copyfile(copy_from, tmp)) end
  local ok, res = pcall(fn, { GIT_INDEX_FILE = tmp }); pcall(vim.uv.fs_unlink, tmp); assert(ok, res); return res
end
local function commit_tree(root, tree, parent, msg)
  local r = git.run(root, (parent and parent ~= "") and { "commit-tree", tree, "-p", parent, "-m", msg } or { "commit-tree", tree, "-m", msg })
  return r.ok and vim.trim(r.stdout) or nil, r.stderr
end
local function snap_worktree(info, b_tree, t1, t2)
  local cands, seen = {}, {}
  for _, list in ipairs({ tree_paths(info.root, b_tree, t1), tree_paths(info.root, b_tree, t2) }) do
    for _, p in ipairs(list) do if p ~= "" and not seen[p] and vim.uv.fs_stat(info.root .. "/" .. p) then seen[p], cands[#cands + 1] = true, p end end
  end
  return with_tmp_index(info.git_dir .. "/index", function(env)
    git.run(info.root, { "add", "-u" }, { env = env, ident = false })
    if #cands > 0 then git.run(info.root, vim.list_extend({ "add", "-f", "--" }, cands), { env = env, ident = false }) end
    local wt = git.run(info.root, { "write-tree" }, { env = env, ident = false })
    return wt.ok and vim.trim(wt.stdout) or nil
  end)
end

function M.merge_trees(root, base_tree, ours_tree, theirs_tree)
  local r = git.run(root, { "merge-tree", "--write-tree", "-z", "--no-messages", "--merge-base=" .. base_tree, ours_tree, theirs_tree }, { ident = false })
  if r.code ~= 0 and r.code ~= 1 then return { ok = false, error = vim.trim(r.stderr ~= "" and r.stderr or r.stdout) } end
  local parts = vim.split(r.stdout, "\0", { plain = true })
  local conflicts, seen = {}, {}
  for i = 2, #parts do
    local p = parts[i]:match("^%d+%s+%x+%s+[123]\t(.+)$")
    if p and not seen[p] then seen[p], conflicts[#conflicts + 1] = true, p end
  end
  table.sort(conflicts)
  return { ok = true, clean = r.code == 0, tree = vim.trim(parts[1] or ""), conflicts = conflicts }
end

local function materialize_tree(root, from_tree, to_tree)
  if from_tree == to_tree then vim.cmd("silent! checktime"); return { changed = {}, deleted = {} } end
  local toks = vim.split(git.run(root, { "diff-tree", "-r", "-z", "--name-status", from_tree, to_tree }, { ident = false }).stdout or "", "\0", { plain = true, trimempty = true })
  local co, del = {}, {}
  for i = 1, #toks, 2 do if toks[i] and toks[i + 1] then if toks[i]:sub(1, 1) == "D" then del[#del + 1] = toks[i + 1] else co[#co + 1] = toks[i + 1] end end end
  for _, p in ipairs(del) do pcall(vim.uv.fs_unlink, root .. "/" .. p) end
  if #co > 0 then with_tmp_index(nil, function(env) git.run(root, { "read-tree", to_tree }, { env = env, ident = false }); git.run(root, vim.list_extend({ "checkout-index", "-f", "--" }, co), { env = env, ident = false }) end) end
  vim.cmd("silent! checktime"); return { changed = co, deleted = del }
end

function M.synced_lookup(root, base, synced_sha, state)
  local map, check_anc = {}, (synced_sha and base and synced_sha ~= base)
  for _, id in ipairs((state and state.applied_ids) or {}) do map[id] = true end
  return function(it) return it.review_status ~= "stale" and (((it.subcommit_id and map[it.subcommit_id]) or map[it.sha] or (check_anc and git.is_ancestor(root, it.sha, synced_sha))) and true or false) end
end
function M.preview_conflicts(info, base, synced_sha, items)
  local base_t = #items > 0 and tree_of(info.root, synced_sha or base) or nil; if not base_t then return {} end
  local ours_t, res = snap_worktree(info, tree_of(info.root, base), base_t, tree_of(info.root, items[#items].sha)), {}
  for _, it in ipairs(ours_t and items or {}) do
    if not it.synced then local m = M.merge_trees(info.root, tree_of(info.root, it.parent), ours_t, tree_of(info.root, it.sha)); res[it.sha] = (m.ok and not m.clean) or false end
  end
  return res
end

local function select_targets(items, target, opts)
  if target == nil or target == "" or target == "approved" then
    local sel = vim.tbl_filter(function(it) return it.review_status == "approved" end, items)
    return sel, (opts.mode ~= "cherry" and #sel > 0 and sel[#sel].index == #sel) and "prefix" or "cherry"
  elseif target == "all" then return vim.list_slice(items, 1, #items), opts.mode == "cherry" and "cherry" or "prefix" end
  local found = git.find_item(items, target); if not found then return nil, nil, "target subcommit not found: " .. tostring(target) end
  return opts.mode == "cherry" and { found } or vim.list_slice(items, 1, found.index), opts.mode == "cherry" and "cherry" or "prefix"
end

function M.apply(info, session, items, target, opts)
  opts = opts or {}; maybe_save()
  local s, root = config.resolve_session(session), info.root
  local base = git.rev_parse(root, config.ref(s, "base")); if not base then return { ok = false, error = "session not initialized: " .. s } end
  local prev_synced, state = git.rev_parse(root, config.ref(s, "synced")) or base, git.read_state(root, s)
  local selected, mode, err = select_targets(items, target, opts); if not selected then return { ok = false, error = err } end
  local unapplied = vim.tbl_filter(function(it) return not it.synced end, selected)
  if #unapplied == 0 then return { ok = true, noop = true, synced = prev_synced } end
  for _, it in ipairs(mode == "prefix" and items or {}) do if it.index > selected[#selected].index and it.synced then mode = "cherry"; break end end
  local prev_synced_tree, target_tree, new_synced = tree_of(root, prev_synced), nil, nil
  if mode == "prefix" then new_synced = selected[#selected].sha; target_tree = tree_of(root, new_synced) else
    target_tree = prev_synced_tree
    for _, it in ipairs(unapplied) do
      local cm = M.merge_trees(root, tree_of(root, it.parent), target_tree, tree_of(root, it.sha))
      if not cm.ok or not cm.clean then return { ok = false, conflict = true, conflicts = cm.conflicts or {}, error = "cherry conflict at " .. (it.short_sha or it.sha) } end
      target_tree = cm.tree
    end
  end
  local real_ours = snap_worktree(info, tree_of(root, base), prev_synced_tree, target_tree)
  if not real_ours then return { ok = false, error = "failed to snapshot working tree" } end
  local merged = M.merge_trees(root, prev_synced_tree, real_ours, target_tree)
  if not merged.ok then return { ok = false, error = merged.error } end
  if not merged.clean then return { ok = false, conflict = true, conflicts = merged.conflicts, error = "merge conflict with local edits (revert local changes first)" } end
  local undo_msg = string.format("agent-track: undo\n\nRestores-Synced: %s\nRestores-Applied: %s\n", prev_synced, table.concat(state.applied_ids or {}, ","))
  local undo_sha, uerr = commit_tree(root, real_ours, git.rev_parse(root, config.ref(s, "undo")), undo_msg)
  if not undo_sha then return { ok = false, error = uerr } end; git.update_ref(root, config.ref(s, "undo"), undo_sha, "undo push")
  local mat = materialize_tree(root, real_ours, merged.tree)
  local applied_ids, seen = {}, {}
  for _, id in ipairs(state.applied_ids or {}) do seen[id], applied_ids[#applied_ids + 1] = true, id end
  for _, it in ipairs(selected) do local k = it.subcommit_id or it.sha; if not seen[k] then seen[k], applied_ids[#applied_ids + 1] = true, k end end
  if mode ~= "prefix" then
    local sc, serr = commit_tree(root, target_tree, prev_synced, "agent-track: cherry sync\n\nApplied-Subcommits: " .. table.concat(vim.tbl_map(function(it) return it.subcommit_id or it.short_sha end, unapplied), ",") .. "\n")
    if not sc then return { ok = false, error = serr } end; new_synced = sc
  end
  git.update_ref(root, config.ref(s, "synced"), new_synced, "sync " .. mode)
  state.applied_ids = applied_ids; git.write_state(root, s, state)
  return { ok = true, clean = true, mode = mode, synced = new_synced, applied = #unapplied, changed = mat.changed, deleted = mat.deleted }
end

function M.undo(info, session)
  local s, root = config.resolve_session(session), info.root; local undo_ref = config.ref(s, "undo")
  local undo_sha = git.rev_parse(root, undo_ref); if not undo_sha then return { ok = false, error = "nothing to undo" } end
  maybe_save()
  local base, undo_tree = git.rev_parse(root, config.ref(s, "base")), tree_of(root, undo_sha)
  local cur_synced, cur_state, b_tree = git.rev_parse(root, config.ref(s, "synced")) or base, git.read_state(root, s), (base and tree_of(root, base) or undo_tree)
  local cur_tree = snap_worktree(info, b_tree, tree_of(root, cur_synced) or b_tree, undo_tree)
  if not cur_tree then return { ok = false, error = "failed to snapshot worktree" } end
  local mat = materialize_tree(root, cur_tree, undo_tree)
  local mf = vim.split(vim.trim(git.run(root, { "log", "-1", "--format=%P%x00%(trailers:key=Restores-Synced,valueonly=true,separator=%x09)%x00%(trailers:key=Restores-Applied,valueonly=true,separator=%x09)", undo_sha }, { ident = false }).stdout or ""), "\0", { plain = true })
  local parent_undo, rest_synced, rest_app = vim.split(mf[1] or "", " ", { plain = true, trimempty = true })[1], vim.trim(mf[2] or ""), vim.trim(mf[3] or "")
  if rest_synced ~= "" then git.update_ref(root, config.ref(s, "synced"), rest_synced, "undo synced") end
  cur_state.applied_ids = rest_app ~= "" and vim.split(rest_app, ",", { plain = true, trimempty = true }) or {}
  git.write_state(root, s, cur_state)
  if parent_undo and parent_undo ~= "" then git.update_ref(root, undo_ref, parent_undo, "undo pop") else git.delete_ref(root, undo_ref) end
  return { ok = true, restored_synced = rest_synced, changed = mat.changed, deleted = mat.deleted }
end
return M
