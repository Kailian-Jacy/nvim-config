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
  -- Determine tmux session name
  if kind == "global" then
    inst.tmux_session = tmux.global_session_name()
  else
    inst.tmux_session = tmux.session_name_for_tab()
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

  -- Now termopen in the current window/buffer
  local cmd, err_file = tmux.build_cmd(inst.tmux_session)
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

--- Setup autocmds for state synchronization
function M.setup()
  local group = vim.api.nvim_create_augroup("FloatTerm", { clear = true })

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
          -- Kill the job if still running
          if loc.jobid then
            pcall(vim.fn.jobstop, loc.jobid)
          end
          -- Close buffer
          if loc.bufnr and vim.api.nvim_buf_is_valid(loc.bufnr) then
            pcall(vim.api.nvim_buf_delete, loc.bufnr, { force = true })
          end
          -- Close window if somehow still valid
          if loc.winid and vim.api.nvim_win_is_valid(loc.winid) then
            pcall(vim.api.nvim_win_close, loc.winid, true)
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

  -- Clean up on TermClose
  vim.api.nvim_create_autocmd("TermClose", {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      -- Check if this is our global terminal
      if state.global.bufnr == bufnr then
        state.global.bufnr = nil
        state.global.jobid = nil
        -- Close all global windows
        if state.global.winids then
          for tab, wid in pairs(state.global.winids) do
            if wid and vim.api.nvim_win_is_valid(wid) then
              pcall(vim.api.nvim_win_close, wid, true)
            end
            state.global.winids[tab] = nil
          end
        end
        if state.global.winid and vim.api.nvim_win_is_valid(state.global.winid) then
          vim.api.nvim_win_close(state.global.winid, true)
        end
        state.global.winid = nil
        state.global.visible = false
      end
      -- Check local terminals
      for _, loc in pairs(state.locals) do
        if loc.bufnr == bufnr then
          loc.bufnr = nil
          loc.jobid = nil
          if loc.winid and vim.api.nvim_win_is_valid(loc.winid) then
            vim.api.nvim_win_close(loc.winid, true)
          end
          loc.winid = nil
          loc.visible = false
        end
      end
    end,
  })

  -- Lazygit command (independent of float terminal system)
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
      end,
    })
  end, { nargs = "?" })
end

return M
