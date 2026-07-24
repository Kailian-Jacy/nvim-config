-- agent-merge.watch — minimal single-file change watcher.
--
-- Prefers libuv fs_event (inotify on Linux, FSEvents on macOS, ...). Falls back
-- to fs_poll on filesystems that cannot push notifications. Both backends
-- deliver the same `on_change(path)` callback, scheduled on the main loop.

local uv = vim.uv or vim.loop

local M = {}
M.DEFAULT_POLL_MS = 2000

local function close(h)
  if h then
    pcall(function() h:stop() end)
    pcall(function() h:close() end)
  end
end

--- Watch a single file for on-disk changes.
--- @param path string                    file to watch
--- @param on_change fun(path: string)     called (scheduled) on each change
--- @param opts? { poll_ms?: integer }     poll interval for the fallback (ms)
--- @return table|nil handle               pass to M.unwatch(); nil if unwatchable
function M.watch(path, on_change, opts)
  local poll_ms = (opts and opts.poll_ms) or M.DEFAULT_POLL_MS
  path = uv.fs_realpath(path) or path
  if vim.fn.filereadable(path) ~= 1 then return nil end

  local handle = { path = path }

  local function fire(rearm)
    vim.schedule(function()
      if handle.stopped then return end
      on_change(path)
      if rearm and not handle.stopped then handle.arm() end
    end)
  end

  -- (re)arm the live backend; re-armable so event-mode survives atomic saves
  -- (write-temp + rename swaps the inode and orphans the old inotify watch).
  function handle.arm()
    close(handle.backend)

    local ev = uv.new_fs_event()
    if ev and pcall(function()
      assert(ev:start(path, {}, function(err, _, events)
        fire(err ~= nil or (events and events.rename))
      end))
    end) then
      handle.backend, handle.kind = ev, "event"
      return
    end
    close(ev)

    -- fs_poll watches by path, so it naturally follows rename-replacement.
    local poll = uv.new_fs_poll()
    if poll and pcall(function()
      assert(poll:start(path, poll_ms, function(err)
        if not err then fire(false) end
      end))
    end) then
      handle.backend, handle.kind = poll, "poll"
      return
    end
    close(poll)
    handle.backend, handle.kind = nil, nil
  end

  handle.arm()
  return handle.backend and handle or nil
end

--- Stop a watcher returned by M.watch().
--- @param handle table|nil
function M.unwatch(handle)
  if not handle then return end
  handle.stopped = true
  close(handle.backend)
  handle.backend = nil
end

return M
