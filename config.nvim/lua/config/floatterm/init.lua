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
function M.toggle_global()
  if state.global.visible and state.global.winid and vim.api.nvim_win_is_valid(state.global.winid) then
    -- Check if the visible window is on this tabpage
    local win_tab = vim.api.nvim_win_get_tabpage(state.global.winid)
    if win_tab == vim.api.nvim_get_current_tabpage() then
      M.hide(state.global)
      return
    end
  end
  -- Not visible on this tab, show it
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
  inst.winid = window.open(inst.bufnr, inst.slot)
  inst.visible = true
  vim.cmd("startinsert")
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
  inst.winid = window.open(bufnr, inst.slot)
  inst.visible = true

  -- Now termopen in the current window/buffer
  local cmd = tmux.build_cmd(inst.tmux_session)
  inst.jobid = vim.fn.termopen(cmd)

  -- Buffer settings
  vim.bo[bufnr].buflisted = false

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

  inst.slot = new_slot
  window.reposition(inst.winid, new_slot)
end

--- Resolve conflicts: hide any terminal occupying target_slot that isn't the requester
---@param target_slot SlotPosition
---@param requester "global"|"local"
function M.resolve_conflict(target_slot, requester)
  local occupant = state:slot_occupant(target_slot)
  if occupant and occupant ~= requester then
    if occupant == "global" then
      M.hide(state.global)
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

--- Check if currently focused on a float terminal window
---@return boolean
function M.is_in_float_terminal()
  return M.get_focused_terminal() ~= nil
end

--- Setup autocmds for state synchronization
function M.setup()
  local group = vim.api.nvim_create_augroup("FloatTerm", { clear = true })

  -- Sync state when window is closed externally
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      local closed_win = tonumber(args.match)
      if not closed_win then return end
      if state.global.winid == closed_win then
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
