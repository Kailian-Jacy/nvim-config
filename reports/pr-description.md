## Extract Script Runner into Standalone nvim-runner Plugin

### Summary

Migrated the script runner functionality (`RunScript`, `RunTest`, `SetBufRunner`) from `autocmds.lua` into a standalone `nvim-runner` plugin with a proper `setup()` API.

### Changes

- **New**: `nvim-runner/` - standalone plugin directory with full test suite
- **New**: `config.nvim/lua/plugins/runner.lua` - lazy.nvim integration
- **Modified**: `config.nvim/lua/config/autocmds.lua` - removed 245 lines of runner code
- **Modified**: `config.nvim/lua/config/keymaps.lua` - updated C-c handler to use plugin module

### Bug Fixes

| # | Bug | Fix | Location |
|---|-----|-----|----------|
| 1 | `string(obj.code)` - `string` is not a Lua global function | Changed to `tostring(obj.code)` | runner.lua |
| 2 | Timeout operator precedence: `a and b == "number" or c > 0` | Fixed to `a and (b == "number" and c > 0)` | runner.lua |
| 3 | Timeout units mixed: seconds in config but `vim.defer_fn` uses ms | All timeouts now in milliseconds (3000, 5000) | config.lua |
| 4 | `vim.log.level.INFO` (missing 's') | Fixed to `vim.log.levels.INFO` | runner.lua |
| 5 | `require('venv-selector')` crashes without plugin | Wrapped in `pcall` with fallback | config.lua |
| 6 | `_current_runner` race condition: killed in callback | Kill before starting new runner | runner.lua |

### Plugin API

```lua
require('nvim-runner').setup({
  runners = { python = {...}, lua = {...}, sh = {...}, nu = {...} },
  timeout = 3000,        -- ms
  insert_result = true,
  keymaps = { run = { "<c-s-cr>", "<d-s-cr>" } },
})
```

### Test Results

```
68 passed, 0 failed, 1 skipped (nushell not available)
```

Tests cover: config, util, command registration, lua/sh/python/nushell runners, timeouts, SetBufRunner, buffer-local overrides, RunTest, kill_current, race conditions, all fixed bugs, empty buffers, special characters, unicode, insert_result toggle, function templates, abort paths, invalid types, and idempotency.
