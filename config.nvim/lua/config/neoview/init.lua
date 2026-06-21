--- Neoview — External renderer framework for Neovim via Tauri
--- Usage: :Extern markdown [render|stop|reload]
local M = {}

M.config = {
  markdown = {
    bin = vim.fn.stdpath("config") .. "/../neoview/target/release/neoview",
    dir = vim.fn.stdpath("config") .. "/../neoview/config",
    events = { "BufWritePost", "InsertLeave", "TextChanged" },
  },
}

-- Per-renderer state
local renderers = {}

--- Extract a color from a highlight group.
--- Returns hex string or nil.
---@param group string
---@param attr "fg"|"bg"
---@return string|nil
local function hl_color(group, attr)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if not ok or not hl then return nil end
  local val = hl[attr]
  if not val then return nil end
  return string.format("#%06x", val)
end

--- Build theme table from current Neovim colorscheme.
---@param overrides table|nil
---@return table<string, string>
local function build_theme(overrides)
  local bg = hl_color("Normal", "bg") or "#13103d"
  local fg = hl_color("Normal", "fg") or "#F8F8F2"
  local comment = hl_color("Comment", "fg") or "#6272A4"
  local selection = hl_color("Visual", "bg") or "#2D4263"

  -- Derive secondary/code bg by shifting main bg slightly
  local function darken(hex, amount)
    local r = math.max(0, tonumber(hex:sub(2, 3), 16) - amount)
    local g = math.max(0, tonumber(hex:sub(4, 5), 16) - amount)
    local b = math.max(0, tonumber(hex:sub(6, 7), 16) - amount)
    return string.format("#%02x%02x%02x", r, g, b)
  end
  local function lighten(hex, amount)
    local r = math.min(255, tonumber(hex:sub(2, 3), 16) + amount)
    local g = math.min(255, tonumber(hex:sub(4, 5), 16) + amount)
    local b = math.min(255, tonumber(hex:sub(6, 7), 16) + amount)
    return string.format("#%02x%02x%02x", r, g, b)
  end

  local theme = {
    ["--bg"] = bg,
    ["--bg-secondary"] = lighten(bg, 10),
    ["--bg-code"] = darken(bg, 8),
    ["--fg"] = fg,
    ["--fg-muted"] = comment,
    ["--border"] = selection,
    ["--selection"] = selection,
    ["--cyan"] = hl_color("Type", "fg") or hl_color("Special", "fg") or "#8BE9FD",
    ["--green"] = hl_color("Function", "fg") or hl_color("@function", "fg") or "#50FA7B",
    ["--orange"] = hl_color("Constant", "fg") or hl_color("@attribute", "fg") or "#FFB86C",
    ["--pink"] = hl_color("Keyword", "fg") or hl_color("Statement", "fg") or "#FF79C6",
    ["--purple"] = hl_color("Number", "fg") or hl_color("@number", "fg") or "#BD93F9",
    ["--red"] = hl_color("Error", "fg") or hl_color("DiagnosticError", "fg") or "#FF5555",
    ["--yellow"] = hl_color("String", "fg") or hl_color("@string", "fg") or "#F1FA8C",
  }

  if overrides then
    for k, v in pairs(overrides) do
      theme[k] = v
    end
  end

  return theme
end

--- Send theme to a running renderer via stdin.
--- Protocol: "THEME:<json>\n"
---@param name string
local function send_theme(name)
  local r = renderers[name]
  if not r or not r.job then return end
  local cfg = M.config[name]
  local theme = build_theme(cfg and cfg.theme_overrides or nil)
  local json = vim.fn.json_encode(theme)
  vim.fn.chansend(r.job, "THEME:" .. json .. "\n")
end

--- Send buffer content to a running renderer via stdin.
--- Protocol: "LINES:<n>\n" followed by n lines of content.
---@param name string
local function send_buffer(name)
  local r = renderers[name]
  if not r or not r.job then return end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local header = string.format("LINES:%d\n", #lines)
  vim.fn.chansend(r.job, header)
  for _, line in ipairs(lines) do
    vim.fn.chansend(r.job, line .. "\n")
  end
end

--- Send cursor position to a running renderer via stdin.
--- Protocol: "CURSOR:<line>:<total_lines>\n"
---@param name string
local function send_cursor(name)
  local r = renderers[name]
  if not r or not r.job then return end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local total = vim.api.nvim_buf_line_count(0)
  vim.fn.chansend(r.job, string.format("CURSOR:%d:%d\n", line, total))
end

--- Send search pattern to renderer.
--- Protocol: "SEARCH:<pattern>\n"
---@param name string
local function send_search(name)
  local r = renderers[name]
  if not r or not r.job then return end
  local pattern = ""
  if vim.v.hlsearch == 1 then
    pattern = vim.fn.getreg("/") or ""
  end
  vim.fn.chansend(r.job, "SEARCH:" .. pattern .. "\n")
end

--- Send visual selection range to renderer.
--- Protocol: "SELECT:<start_line>:<end_line>:<total_lines>\n"
---@param name string
local function send_selection(name)
  local r = renderers[name]
  if not r or not r.job then return end
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local start_line = vim.fn.line("v")
    local end_line = vim.fn.line(".")
    if start_line > end_line then start_line, end_line = end_line, start_line end
    local total = vim.api.nvim_buf_line_count(0)
    vim.fn.chansend(r.job, string.format("SELECT:%d:%d:%d\n", start_line, end_line, total))
  else
    vim.fn.chansend(r.job, "SELECT:0:0:0\n")
  end
end

--- Send current buffer if filetype matches the renderer
---@param name string
local function maybe_send(name)
  if vim.bo.filetype == name then
    send_buffer(name)
  end
end

--- Start a renderer
---@param name string
local function render(name)
  local cfg = M.config[name]
  if not cfg then
    vim.notify("[extern] No renderer configured for: " .. name, vim.log.levels.ERROR)
    return
  end

  local bin = cfg.bin
  if vim.fn.filereadable(bin) == 0 then
    vim.notify("[extern] Binary not found: " .. bin .. "\nRun: cd neoview && cargo build --release", vim.log.levels.ERROR)
    return
  end

  renderers[name] = renderers[name] or {}
  local r = renderers[name]

  if r.job then
    maybe_send(name)
    return
  end

  local env = {}
  if cfg.dir then
    env.NEOVIEW_DIR = vim.fn.resolve(cfg.dir)
  end

  -- Pass Neovim's window position so Tauri opens on the same screen
  local pos = vim.fn.system(
    "osascript -e 'tell application \"System Events\" to get position of first window of (first application process whose frontmost is true)'"
  )
  local x, y = pos:match("(%d+),%s*(%d+)")
  if x and y then
    env.NEOVIM_X = x
    env.NEOVIM_Y = y
  end

  r.job = vim.fn.jobstart({ bin }, {
    stdin = "pipe",
    stdout_buffered = false,
    env = env,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        local path = line:match("^OPEN:(.+)$")
        if path then
          -- Resolve relative paths against current buffer's directory
          if not path:match("^/") then
            local bufdir = vim.fn.expand("%:p:h")
            path = bufdir .. "/" .. path
          end
          path = vim.fn.resolve(path)
          if vim.fn.filereadable(path) == 1 then
            vim.schedule(function() vim.cmd("edit " .. vim.fn.fnameescape(path)) end)
          else
            vim.schedule(function() vim.notify("[extern] File not found: " .. path, vim.log.levels.WARN) end)
          end
        end
        local goto_line = line:match("^GOTO:(%d+)$")
        if goto_line then
          local lnum = tonumber(goto_line)
          vim.schedule(function()
            local total = vim.api.nvim_buf_line_count(0)
            if lnum >= 1 and lnum <= total then
              vim.api.nvim_win_set_cursor(0, { lnum, 0 })
              vim.cmd("normal! zz")
            end
          end)
        end
      end
    end,
    on_exit = function()
      r.job = nil
    end,
  })

  vim.defer_fn(function()
    send_theme(name)
    maybe_send(name)
    send_cursor(name)
  end, 500)
end

--- Stop a renderer
---@param name string
local function stop(name)
  local r = renderers[name]
  if not r or not r.job then return end
  vim.fn.chanclose(r.job, "stdin")
  vim.fn.jobstop(r.job)
  r.job = nil
end

--- Reload (stop + start)
---@param name string
local function reload(name)
  stop(name)
  vim.defer_fn(function() render(name) end, 100)
end

--- Dispatch subcommand
---@param name string
---@param action string|nil
local function dispatch(name, action)
  action = action or "render"
  if action == "render" then
    render(name)
  elseif action == "stop" then
    stop(name)
  elseif action == "reload" then
    reload(name)
  elseif action == "toggle" then
    local r = renderers[name]
    if r and r.job then stop(name) else render(name) end
  else
    vim.notify("[extern] Unknown action: " .. action, vim.log.levels.ERROR)
  end
end

--- Setup autocommands and the :Extern command
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  local group = vim.api.nvim_create_augroup("Extern", { clear = true })

  -- Register autocmds for each configured renderer
  for name, cfg in pairs(M.config) do
    local patterns = { "*." .. name }
    -- markdown also matches .md
    if name == "markdown" then
      patterns = { "*.md", "*.markdown" }
    end

    vim.api.nvim_create_autocmd(cfg.events, {
      group = group,
      pattern = patterns,
      callback = function()
        local r = renderers[name]
        if r and r.job then
          maybe_send(name)
          send_cursor(name)
        end
      end,
    })

    -- Buffer switch: re-send content if new buffer is also markdown
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
      group = group,
      pattern = patterns,
      callback = function()
        local r = renderers[name]
        if r and r.job then
          send_buffer(name)
          send_cursor(name)
        end
      end,
    })

    -- Cursor position sync
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "CursorMoved" }, {
      group = group,
      pattern = patterns,
      callback = function()
        local r = renderers[name]
        if r and r.job then
          send_cursor(name)
          send_selection(name)
        end
      end,
    })

    -- Search highlight sync (CursorMoved catches * and # which bypass CmdlineLeave)
    vim.api.nvim_create_autocmd({ "CmdlineLeave", "CursorMoved" }, {
      group = group,
      pattern = patterns,
      callback = function()
        local r = renderers[name]
        if r and r.job then send_search(name) end
      end,
    })

    -- Visual mode selection sync
    vim.api.nvim_create_autocmd({ "ModeChanged" }, {
      group = group,
      pattern = { "*:[vV\x16]*", "[vV\x16]*:*" },
      callback = function()
        local r = renderers[name]
        if r and r.job then send_selection(name) end
      end,
    })
  end

  -- :Extern markdown [render|stop|reload|toggle]
  vim.api.nvim_create_user_command("Extern", function(cmd)
    local args = vim.split(cmd.args, "%s+", { trimempty = true })
    local name = args[1]
    local action = args[2] -- nil defaults to "render"
    if not name then
      vim.notify("[extern] Usage: :Extern <renderer> [render|stop|reload|toggle]", vim.log.levels.WARN)
      return
    end
    dispatch(name, action)
  end, {
    nargs = "+",
    desc = "External renderer — :Extern <name> [render|stop|reload|toggle]",
    complete = function(_, cmdline, _)
      local parts = vim.split(cmdline, "%s+", { trimempty = true })
      local trailing_space = cmdline:match("%s$") ~= nil
      local nargs = #parts + (trailing_space and 1 or 0)
      if nargs <= 2 then
        -- Complete renderer names
        return vim.tbl_keys(M.config)
      elseif nargs == 3 then
        -- Complete actions
        return { "render", "stop", "reload", "toggle" }
      end
      return {}
    end,
  })


  -- Keymap target for cmd_mappings dispatch
  vim.keymap.set("n", "<leader>mp", function() dispatch("markdown", "toggle") end, { desc = "Toggle Extern markdown" })
end

return M
