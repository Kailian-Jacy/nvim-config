local M = {}
local state = require("config.floatterm.state")
local window = require("config.floatterm.window")
local tmux = require("config.floatterm.tmux")

--- Toggle local terminal (per-tab)
function M.toggle_local()
  local inst = state:get_local()
  if inst.visible then
    M.hide(inst)
  else
    M.show(inst, "local")
  end
end

-- @AI: Split iterm2 related logic to a submodule inside floatterm to be external/iterm2.

--- iTerm2-aware toggle for the per-tab local terminal.
--- Behaviour when the float is *not* already visible (i.e. about to open):
---   1. if the tab's tmux session is already attached in a running iTerm2 tab,
---      focus that tab instead of opening a duplicate float;
---   2. otherwise (iTerm2 not running/installed, or the session isn't open
---      there) open the local termlocal as usual.
--- When the float *is* visible this is a plain toggle (hide), unchanged.
function M.smart_toggle_local()
  local inst = state:get_local()
  if inst.visible then
    -- Already on screen: normal toggle-close.
    M.hide(inst)
    return
  end
  -- If the local terminal buffer/job is still alive here, this Neovim is the
  -- tmux client (session lives in-editor), so skip the iTerm2 hand-back and
  -- just reopen the float.
  local job_alive = inst.jobid and vim.fn.jobwait({ inst.jobid }, 0)[1] == -1
  if not job_alive then
    local session = tmux.session_name_for_tab()
    if M.focus_session_in_iterm(session) then
      return
    end
  end
  M.show(inst, "local")
end

--- Try to focus a running iTerm2 tab marked with `session` (the iTerm2 user
--- variable `user.nvim_session`, set at hand-off time). Returns true only if
--- such a tab was found and focused. Every failure path (no osascript, iTerm2
--- not running/installed, or no tab carrying the mark) returns false so the
--- caller can fall back. The check is done in real time, so a closed iTerm2 tab
--- simply isn't found here.
---@param session string
---@return boolean
function M.focus_session_in_iterm(session)
  if not session or session == "" then return false end
  local script = vim.fn.stdpath("config") .. "/scripts/iterm_focus_session.applescript"
  if vim.fn.executable("osascript") ~= 1 or vim.fn.filereadable(script) ~= 1 then
    return false
  end

  local res = vim.system(
    { "osascript", script, session },
    { text = true }
  ):wait()
  return res.code == 0 and vim.trim(res.stdout or "") == "focused"
end

--- Toggle global terminal (shared buffer across tabs)
--- Issue #3: global.winid is now table<tabpage, winid> to handle cross-tab properly
function M.toggle_global()
  local tab = vim.api.nvim_get_current_tabpage()
  local winid = state.global.winids and state.global.winids[tab]

  if winid and vim.api.nvim_win_is_valid(winid) then
    -- Visible on this tab, hide it
    M.hide_global_on_tab(tab)
    return
  end

  -- Not visible on this tab, show it (reuse buffer)
  M.show(state.global, "global")
end

--- Show a terminal instance
---@param inst TerminalInstance
---@param kind "global"|"local"
function M.show(inst, kind)
  -- Conflict management: hide any other terminal occupying the same slot
  M.resolve_conflict(inst.slot, kind)

  -- If the buffer doesn't exist or is invalid, spawn a new one
  if not inst.bufnr or not vim.api.nvim_buf_is_valid(inst.bufnr) then
    M.spawn(inst, kind)
    return -- spawn already creates the window and sets visible
  end

  -- Buffer exists, just open a new floating window for it
  local winid = window.open(inst.bufnr, inst.slot)

  if kind == "global" then
    local tab = vim.api.nvim_get_current_tabpage()
    if not state.global.winids then state.global.winids = {} end
    state.global.winids[tab] = winid
    -- Keep legacy field for compat with get_focused_terminal
    state.global.winid = winid
  else
    inst.winid = winid
  end
  inst.visible = true

  -- Issue #9: check job is valid before startinsert
  if inst.jobid and vim.fn.jobwait({ inst.jobid }, 0)[1] == -1 then
    vim.cmd("startinsert")
  end
end

--- Hide a terminal instance (close window, keep buffer)
---@param inst TerminalInstance
function M.hide(inst)
  if inst.winid and vim.api.nvim_win_is_valid(inst.winid) then
    vim.api.nvim_win_close(inst.winid, true)
  end
  inst.winid = nil
  inst.visible = false
end

--- Hide global terminal on a specific tab
---@param tab integer
function M.hide_global_on_tab(tab)
  if not state.global.winids then return end
  local winid = state.global.winids[tab]
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
  state.global.winids[tab] = nil
  -- Update visible: true if any tab still shows it
  state.global.visible = false
  if state.global.winids then
    for _, wid in pairs(state.global.winids) do
      if wid and vim.api.nvim_win_is_valid(wid) then
        state.global.visible = true
        state.global.winid = wid
        break
      end
    end
  end
  if not state.global.visible then
    state.global.winid = nil
  end
end

--- Spawn a new terminal buffer with tmux
---@param inst TerminalInstance
---@param kind "global"|"local"
function M.spawn(inst, kind)
  -- Ensure the (global) tmux server is up before spawning a session.
  tmux.ensure_server()

  -- Determine tmux session name
  if kind == "global" then
    inst.tmux_session = tmux.global_session_name()
  else
    inst.tmux_session = tmux.session_name_for_tab()
    -- Bind this tab to its dscc task (same name as the local/tmux session,
    -- which is what `dscc run <session>` creates/attaches).
    pcall(vim.fn.settabvar, vim.fn.tabpagenr(), "dscc_task", inst.tmux_session)
  end

  -- Create scratch buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  inst.bufnr = bufnr

  -- Open floating window first (this makes buf current without flash)
  local winid = window.open(bufnr, inst.slot)
  inst.visible = true

  if kind == "global" then
    local tab = vim.api.nvim_get_current_tabpage()
    if not state.global.winids then state.global.winids = {} end
    state.global.winids[tab] = winid
    state.global.winid = winid
  else
    inst.winid = winid
  end

  -- Now open terminal in the current window/buffer
  local cmd, err_file = tmux.build_cmd(inst.tmux_session)

  -- Use standard termopen for both local and global terminals.
  -- Bell detection for local terminals is handled via tmux alert-bell hook.
  inst.jobid = vim.fn.termopen(cmd, {
    on_exit = function(_, _, _)
      vim.schedule(function()
        if err_file and vim.fn.filereadable(err_file) == 1 then
          local err_msg = vim.fn.readfile(err_file)
          vim.fn.delete(err_file)
          vim.notify(
            string.format(
              "[floatterm] boot failed: %s\ncmd: %s",
              table.concat(err_msg, "\n"),
              table.concat(cmd, " ")
            ),
            vim.log.levels.ERROR
          )
        end
      end)
    end,
  })

  -- Install tmux bell hook for local terminals
  if kind == "local" and inst.tmux_session then
    tmux.install_bell_hook(inst.tmux_session)
  end

  -- Buffer settings
  vim.bo[bufnr].buflisted = false
  if kind == "local" then
    vim.bo[bufnr].filetype = "termlocal"
  else
    vim.bo[bufnr].filetype = "termglobal"
  end

  vim.cmd("startinsert")
end



--- Move a terminal to a new slot
---@param inst TerminalInstance
---@param new_slot SlotPosition
---@param kind "global"|"local"
function M.move_to_slot(inst, new_slot, kind)
  if not inst.visible then return end
  if inst.slot == new_slot then return end

  -- Resolve conflicts at the new slot
  M.resolve_conflict(new_slot, kind)

  local old_slot = inst.slot
  inst.slot = new_slot

  local winid = inst.winid
  if kind == "global" then
    local tab = vim.api.nvim_get_current_tabpage()
    winid = state.global.winids and state.global.winids[tab] or inst.winid
  end

  -- Guard: prevent WinClosed autocmd from marking visible=false during reposition
  state._repositioning = true
  local ok, new_winid = pcall(window.reposition, winid, inst.bufnr, old_slot, new_slot)
  state._repositioning = false

  if ok and new_winid then
    if kind == "global" then
      local tab = vim.api.nvim_get_current_tabpage()
      state.global.winids[tab] = new_winid
      state.global.winid = new_winid
    else
      inst.winid = new_winid
    end
    inst.visible = true  -- Restore visible state after reposition
  elseif not ok then
    -- Reposition failed; mark as hidden since window state is uncertain
    inst.visible = false
    inst.winid = nil
    vim.notify("[floatterm] reposition failed: " .. tostring(new_winid), vim.log.levels.WARN)
  end
end

--- Resolve conflicts: hide any terminal occupying target_slot that isn't the requester
---@param target_slot SlotPosition
---@param requester "global"|"local"
function M.resolve_conflict(target_slot, requester)
  local occupant = state:slot_occupant(target_slot)
  if occupant and occupant ~= requester then
    if occupant == "global" then
      local tab = vim.api.nvim_get_current_tabpage()
      M.hide_global_on_tab(tab)
    else
      M.hide(state:get_local())
    end
  end
end

--- Shift the focused terminal's position
---@param direction "h"|"j"|"k"|"l"
function M.shift_position(direction)
  local inst, kind = M.get_focused_terminal()
  if not inst then return end

  local new_slot
  if direction == "h" then
    new_slot = "left"
  elseif direction == "l" then
    new_slot = "right"
  else -- j or k
    new_slot = "centered"
  end

  if new_slot and new_slot ~= inst.slot then
    M.move_to_slot(inst, new_slot, kind)
  end
end

--- Reset the focused terminal's position to centered
function M.reset_position()
  local inst, kind = M.get_focused_terminal()
  if not inst then return end
  if inst.slot ~= "centered" then
    M.move_to_slot(inst, "centered", kind)
  end
end

--- Get the currently focused terminal instance (if cursor is in one)
---@return TerminalInstance|nil, "global"|"local"|nil
function M.get_focused_terminal()
  local cur_win = vim.api.nvim_get_current_win()

  -- Check global winids for current tab
  if state.global.winids then
    local tab = vim.api.nvim_get_current_tabpage()
    if state.global.winids[tab] == cur_win then
      return state.global, "global"
    end
  end
  -- Legacy fallback
  if state.global.winid == cur_win then
    return state.global, "global"
  end

  local loc = state:get_local()
  if loc and loc.winid == cur_win then
    return loc, "local"
  end
  return nil, nil
end

--- Check if current buffer is a terminal buffer
---@return boolean
function M.is_terminal_buffer()
  return vim.bo.buftype == "terminal"
end

--- Check if currently focused on a managed terminal window (float or split)
---@return boolean
function M.is_in_terminal()
  return M.get_focused_terminal() ~= nil
end

--- Backward compat alias
M.is_in_float_terminal = M.is_in_terminal

--- Hand off the focused local terminal's tmux session to a fresh iTerm2 window.
--- Closes (detaches) the current termlocal buffer so this Neovim client leaves
--- the tmux session, then reattaches the *same* session in iTerm2 via
--- AppleScript, reusing the floatterm tmux command assembly. A tab-local var
--- keyed by the session name guards against launching more than one iTerm
--- attach for the same session on the same tab.
function M.handoff_local_to_iterm()
  local inst, kind = M.get_focused_terminal()
  if not inst or kind ~= "local" then
    -- @TODO
    vim.notify("Cmd-Shift-A: not in a local (termlocal) terminal.", vim.log.levels.WARN)
    return
  end
  local session = inst.tmux_session
  if not session or session == "" then
    vim.notify("Cmd-Shift-A: no tmux session bound to this terminal.", vim.log.levels.WARN)
    return
  end

  -- Duplication guard, checked in real time against iTerm2 itself: if a tab is
  -- already marked with this session (user.nvim_session), just focus it instead
  -- of opening a duplicate. The mark lives on the iTerm2 tab, so a closed tab is
  -- simply not found and we proceed with a fresh hand-off.
  if M.focus_session_in_iterm(session) then
    vim.notify(
      ("Cmd-Shift-A: session '%s' is already open in iTerm2 — focused it."):format(session),
      vim.log.levels.INFO
    )
    return
  end

  -- Reuse the floatterm tmux command assembly so iTerm2 runs an identical
  -- `new-session -As` (attach-if-exists) invocation on the same server socket.
  local cmd_string = tmux.attach_cmd_string(session)
  local script = vim.fn.stdpath("config") .. "/scripts/iterm_attach_session.applescript"

  -- osascript can't run inside the dev container (no macOS/iTerm2). Detect that
  -- and bail out *without* closing the buffer so the session stays usable.
  if vim.fn.executable("osascript") ~= 1 or vim.fn.filereadable(script) ~= 1 then
    vim.notify(
      "Cmd-Shift-A: osascript/applescript unavailable; skipping iTerm2 handoff.\n"
        .. "attach manually with: " .. cmd_string,
      vim.log.levels.WARN
    )
    return
  end

  vim.system({ "osascript", script, cmd_string, session }, { text = true }, function(obj)
    if obj.code ~= 0 then
      vim.schedule(function()
        vim.notify(
          "Cmd-Shift-A: iTerm2 attach failed:\n" .. (obj.stderr ~= "" and obj.stderr or obj.stdout or ""),
          vim.log.levels.ERROR
        )
      end)
    end
  end)

  -- Close the current termlocal buffer. Terminating the tmux client job detaches
  -- this Neovim instance from the session (SIGHUP); the session persists on the
  -- shared server and is now owned by the iTerm2 window we just opened.
  M.hide(inst)
  if inst.bufnr and vim.api.nvim_buf_is_valid(inst.bufnr) then
    pcall(vim.api.nvim_buf_delete, inst.bufnr, { force = true })
  end
end

--- Handle terminal bell from a tmux session hook.
--- Called via the global FloatTermBellHook() function.
--- Finds the tab owning the tmux session and marks it as beeping.
---@param session_name string
function M._on_term_bell(session_name)
  -- Find which tab owns this tmux session
  local owner_tab = nil
  local owner_bufnr = nil
  for tab, inst in pairs(state.locals) do
    if inst.tmux_session == session_name then
      owner_tab = tab
      owner_bufnr = inst.bufnr
      break
    end
  end

  if not owner_tab then return end

  -- Don't mark if the terminal buffer is currently focused
  if owner_bufnr and vim.api.nvim_get_current_buf() == owner_bufnr then
    return
  end

  -- Mark the tab as beeping
  local beep_set = vim.g._tab_beep or {}
  beep_set[tostring(owner_tab)] = true
  vim.g._tab_beep = beep_set
  vim.cmd("redrawtabline")
end

--- Setup autocmds for state synchronization
function M.setup()
  local group = vim.api.nvim_create_augroup("FloatTerm", { clear = true })

  -- Guard against leaked terminal window options, part 1: inheritance.
  -- Window options (number/signcolumn/...) are copied to windows split off a
  -- terminal window (e.g. a picker or :vsplit opened from inside the float).
  -- Window VARS are not copied, so at WinNew time we look at the window we
  -- were split from: if it is floatterm-owned, reset the new window to editor
  -- defaults.
  vim.api.nvim_create_autocmd("WinNew", {
    group = group,
    callback = function()
      local new_win = vim.api.nvim_get_current_win()
      if vim.w[new_win].floatterm_owned then return end
      local src = vim.fn.win_getid(vim.fn.winnr("#"))
      if src ~= 0 and src ~= new_win and vim.w[src] and vim.w[src].floatterm_owned then
        require("config.floatterm.window").restore_editor_opts(new_win)
      end
    end,
  })

  -- Part 2: in-place replacement. The options survive the terminal buffer
  -- being replaced in the still-open window (e.g. `bdelete!` of a termlocal
  -- buffer puts the next buffer into it). The result was a normal file
  -- rendered with no line numbers, an invisible gitsigns column, and E1513
  -- (winfixbuf) on every buffer switch -- looking like a "terminal" window
  -- that only a restart could fix. Whenever a non-terminal buffer shows up in
  -- a floatterm-marked window, restore editor options.
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_buf(win) ~= args.buf then return end
      if not vim.w[win].floatterm_owned then return end
      if vim.bo[args.buf].buftype == "terminal" then return end
      require("config.floatterm.window").restore_editor_opts(win)
    end,
  })

  -- Sync state when window is closed externally
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      -- Skip state updates during programmatic reposition (close+reopen)
      if state._repositioning then return end

      local closed_win = tonumber(args.match)
      if not closed_win then return end

      -- Check global winids
      if state.global.winids then
        for tab, wid in pairs(state.global.winids) do
          if wid == closed_win then
            state.global.winids[tab] = nil
          end
        end
        -- Update visible state
        local any_visible = false
        for _, wid in pairs(state.global.winids) do
          if wid and vim.api.nvim_win_is_valid(wid) then
            any_visible = true
            state.global.winid = wid
            break
          end
        end
        if not any_visible then
          state.global.winid = nil
          state.global.visible = false
        end
      elseif state.global.winid == closed_win then
        state.global.winid = nil
        state.global.visible = false
      end

      for _, loc in pairs(state.locals) do
        if loc.winid == closed_win then
          loc.winid = nil
          loc.visible = false
        end
      end
    end,
  })

  -- Issue #5: TabClosed handler - clean up local terminal state
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function(args)
      local closed_tab = tonumber(args.match)
      if not closed_tab then return end
      -- Find and clean up the local instance for this tab
      -- Note: TabClosed fires with the tab number (1-based), but our keys are tabpage handles.
      -- We need to check which tabpage handles are no longer valid.
      local valid_tabs = vim.api.nvim_list_tabpages()
      local valid_set = {}
      for _, t in ipairs(valid_tabs) do
        valid_set[t] = true
      end
      for tab, loc in pairs(state.locals) do
        if not valid_set[tab] then
          -- Remove tmux bell hook
          if loc.tmux_session then
            pcall(tmux.remove_bell_hook, loc.tmux_session)
          end
          -- Kill the job if still running
          if loc.jobid then
            pcall(vim.fn.jobstop, loc.jobid)
          end
          -- Close window BEFORE deleting the buffer: deleting first made nvim
          -- put another buffer into the still-open terminal window, which then
          -- kept the terminal window options (no numbers, winfixbuf, ...).
          if loc.winid and vim.api.nvim_win_is_valid(loc.winid) then
            pcall(vim.api.nvim_win_close, loc.winid, true)
          end
          -- Close buffer
          if loc.bufnr and vim.api.nvim_buf_is_valid(loc.bufnr) then
            pcall(vim.api.nvim_buf_delete, loc.bufnr, { force = true })
          end
          state.locals[tab] = nil
        end
      end
      -- Also clean up global winids for closed tabs
      if state.global.winids then
        for tab, _ in pairs(state.global.winids) do
          if not valid_set[tab] then
            state.global.winids[tab] = nil
          end
        end
      end
    end,
  })

  -- Register global function for tmux bell hook RPC callback
  _G.FloatTermBellHook = function(session_name)
    vim.schedule(function()
      M._on_term_bell(session_name)
    end)
    return "ok"
  end

  -- Auto-enter insert mode when entering a terminal buffer
  if vim.g.terminal_auto_insert then
    vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
      group = group,
      callback = function(args)
        if vim.startswith(vim.api.nvim_buf_get_name(args.buf), "term://") then
          vim.cmd("startinsert")
        end
      end,
    })
  end

  -- Terminal buffer settings
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(args)
      if vim.startswith(vim.api.nvim_buf_get_name(args.buf), "term://") then
        vim.bo[args.buf].buflisted = false
        -- gf support in terminal buffer
        vim.keymap.set("n", "gf", function()
          local f = vim.fn.findfile(vim.fn.expand("<cfile>"), "**")
          if f == "" then
            vim.notify("no file under cursor", vim.log.levels.INFO)
          else
            -- Hide any visible terminal first
            local inst, _ = M.get_focused_terminal()
            if inst then
              M.hide(inst)
            end
            vim.cmd("e " .. f)
          end
        end, { buffer = args.buf })
      end
    end,
  })

  -- Cmd-Shift-A (<D-A>): hand off the local tmux session to iTerm2.
  -- Bound buffer-locally on the termlocal filetype so it only fires inside
  -- local terminal buffers ("close the current termlocal buffer").
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "termlocal",
    callback = function(args)
      vim.keymap.set({ "n", "t" }, "<D-A>", function()
        if vim.api.nvim_get_mode().mode == "t" then
          -- Leave terminal mode first so notifications/prompts are interactive,
          -- then run the handoff on the next tick.
          vim.cmd("stopinsert")
          vim.schedule(function() M.handoff_local_to_iterm() end)
        else
          M.handoff_local_to_iterm()
        end
      end, {
        buffer = args.buf,
        desc = "Cmd-Shift-A: hand off local tmux session to iTerm2",
      })
    end,
  })

  -- Clean up on TermClose
  vim.api.nvim_create_autocmd("TermClose", {
    group = group,
    callback = function(args)
      local bufnr = args.buf

      -- Helper: set up 'q' keymap on the dead terminal buffer so the user
      -- can dismiss the window showing [Process exited].
      local function setup_q_to_close(buf)
        if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
        pcall(vim.keymap.set, "n", "q", function()
          -- Find and close any window displaying this buffer
          for _, wid in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_is_valid(wid) and vim.api.nvim_win_get_buf(wid) == buf then
              pcall(function() vim.wo[wid].winfixbuf = false end)
              pcall(vim.api.nvim_win_close, wid, true)
            end
          end
          -- Delete the buffer
          if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          end
        end, { buffer = buf, nowait = true, silent = true })
      end

      -- Check if this is our global terminal
      if state.global.bufnr == bufnr then
        state.global.jobid = nil
        -- Leave window open showing [Process exited]; set up q to close
        setup_q_to_close(bufnr)
      end
      -- Check local terminals
      for _, loc in pairs(state.locals) do
        if loc.bufnr == bufnr then
          -- Remove tmux bell hook
          if loc.tmux_session then
            pcall(tmux.remove_bell_hook, loc.tmux_session)
          end
          loc.jobid = nil
          -- Leave window open showing [Process exited]; set up q to close
          setup_q_to_close(bufnr)
        end
      end
    end,
  })

  -- Lazygit command (independent of float terminal system)
  local lazygit_state = { win = nil, buf = nil }

  vim.api.nvim_create_user_command("Lazygit", function(args)
    local cwd = args.args ~= "" and vim.fn.expand(args.args) or vim.fn.getcwd()
    local buf = vim.api.nvim_create_buf(false, true)
    local width = vim.o.columns
    local height = vim.o.lines - 1
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      row = 0,
      col = 0,
      width = width,
      height = height,
      border = "none",
      style = "minimal",
    })
    lazygit_state.win = win
    lazygit_state.buf = buf
    vim.fn.termopen({ "lazygit" }, { cwd = cwd })
    vim.cmd("startinsert")
    -- Auto-close window when lazygit exits
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = buf,
      once = true,
      callback = function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
        lazygit_state.win = nil
        lazygit_state.buf = nil
      end,
    })
  end, { nargs = "?" })

  -- LazygitEdit: called from lazygit custom command to open a file in nvim.
  -- Hides the lazygit float first, then opens the file.
  vim.api.nvim_create_user_command("LazygitEdit", function(args)
    local file = args.args
    if not file or file == "" then return end
    -- Hide lazygit float (keep buffer alive so lazygit keeps running)
    if lazygit_state.win and vim.api.nvim_win_is_valid(lazygit_state.win) then
      vim.api.nvim_win_hide(lazygit_state.win)
    end
    -- Open the file
    vim.cmd("edit " .. vim.fn.fnameescape(file))
  end, { nargs = 1, complete = "file" })

  -- LazygitHere: open lazygit in the current window (no float)
  vim.api.nvim_create_user_command("LazygitHere", function(args)
    local cwd = args.args ~= "" and vim.fn.expand(args.args) or vim.fn.getcwd()
    local prev_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.fn.termopen({ "lazygit" }, { cwd = cwd })
    vim.cmd("startinsert")
    -- Restore previous buffer when lazygit exits
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = buf,
      once = true,
      callback = function()
        vim.schedule(function()
          local win = vim.api.nvim_get_current_win()
          if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(prev_buf) then
            vim.api.nvim_win_set_buf(win, prev_buf)
          end
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end)
      end,
    })
  end, { nargs = "?" })
end

return M
