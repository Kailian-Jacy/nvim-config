## nvim-runner Plugin - Test Results Report

### Test Execution

- **Date**: 2026-03-06
- **Neovim**: v0.11.6 (LuaJIT 2.1)
- **OS**: Linux 6.8.0 (Ubuntu)
- **Shell**: bash

### Results: 68 passed, 0 failed, 1 skipped

### Detailed Results

#### Config Tests (9 PASS)
- [PASS] config: options exist after setup
- [PASS] config: default timeout is 3000ms
- [PASS] config: default insert_result is true
- [PASS] config: python runner defined
- [PASS] config: lua runner defined
- [PASS] config: sh runner defined
- [PASS] config: nu runner defined
- [PASS] config: custom timeout override works
- [PASS] config: python runner still exists after merge

#### Util Tests (1 PASS)
- [PASS] util: not in visual mode in headless

#### Command Registration Tests (3 PASS)
- [PASS] command: RunScript exists
- [PASS] command: RunTest exists
- [PASS] command: SetBufRunner exists

#### Lua Runner Tests (5 PASS)
- [PASS] lua: basic return value execution
- [PASS] lua: vim.notify from executed code works
- [PASS] lua: syntax error is reported
- [PASS] lua: multiline execution succeeds
- [PASS] lua: nil return (prints 'lua executed.')

#### Shell Runner Tests (3 PASS)
- [PASS] sh: basic echo output inserted into buffer
- [PASS] sh: stderr output captured
- [PASS] sh: multiline script execution

#### Python Runner Tests (4 PASS)
- [PASS] python: basic print output
- [PASS] python: multiline computation
- [PASS] python: unicode output
- [PASS] python: stderr captured

#### Nushell Runner Tests (1 SKIP)
- [SKIP] nu: nushell not available

#### Timeout Tests (2 PASS)
- [PASS] **FIXED_BUG**: timeout kills process (500ms timeout for sleep 30)
- [PASS] timeout: per-runner timeout override works

#### SetBufRunner Tests (5 PASS)
- [PASS] SetBufRunner: buffer runner set
- [PASS] SetBufRunner: sh entry created
- [PASS] SetBufRunner: runner is empty string
- [PASS] SetBufRunner: template contains custom text
- [PASS] SetBufRunner: error on empty filetype

#### Buffer-local Runner Override Tests (1 PASS)
- [PASS] buffer-local: custom runner template overrides default

#### Error Handling Tests (2 PASS)
- [PASS] no filetype: error message shown
- [PASS] unknown filetype: error message for unsupported type

#### RunTest Tests (3 PASS)
- [PASS] RunTest: discovers vimtest files
- [PASS] RunTest: reports test results
- [PASS] RunTest: reports when no test files found
- [PASS] RunTest: handles erroring test files gracefully

#### Kill Runner Tests (3 PASS)
- [PASS] kill_current: returns false when no runner active
- [PASS] kill_current: returns true when killing active runner
- [PASS] kill_current: runner is nil after kill

#### FIXED_BUG Tests (14 PASS)
- [PASS] **FIXED_BUG**: venv-selector pcall protection - no crash without venv-selector
- [PASS] **FIXED_BUG**: race condition - old runner killed before new one starts
- [PASS] **FIXED_BUG**: tostring(obj.code) works correctly
- [PASS] **FIXED_BUG**: string(obj.code) would have errored (confirmed bug)
- [PASS] **FIXED_BUG**: vim.log.levels.INFO exists
- [PASS] **FIXED_BUG**: vim.log.level (without s) is nil - confirms original bug
- [PASS] **FIXED_BUG**: python timeout is 3000ms (was 3)
- [PASS] **FIXED_BUG**: nu timeout is 5000ms (was 5)
- [PASS] **FIXED_BUG**: default timeout is 3000ms
- [PASS] **FIXED_BUG**: original timeout logic crashes with string candidate
- [PASS] **FIXED_BUG**: fixed timeout logic handles string candidate safely
- [PASS] **FIXED_BUG**: fixed timeout logic works with number
- [PASS] **FIXED_BUG**: fixed timeout logic rejects 0
- [PASS] **FIXED_BUG**: fixed timeout logic rejects negative
- [PASS] **FIXED_BUG**: fixed timeout logic handles nil

#### Edge Cases (5 PASS)
- [PASS] empty buffer: no crash on empty sh buffer
- [PASS] empty buffer: no crash on empty lua buffer
- [PASS] special chars: no crash with quotes and shell chars
- [PASS] insert_result=false: output not inserted into buffer
- [PASS] function template: custom function template works

#### Abort/Error Path Tests (4 PASS)
- [PASS] runner abort: runner function returning nil triggers abort message
- [PASS] template abort: template function returning nil triggers abort message
- [PASS] invalid runner: number runner type reported as error
- [PASS] invalid template: number template type reported as error

#### Idempotency Tests (2 PASS)
- [PASS] idempotency: multiple setup calls don't crash
- [PASS] idempotency: RunScript still exists after re-setup

### Fixed Bugs Summary

| Bug | Original Code | Fixed Code | Verified |
|-----|--------------|------------|----------|
| `string()` not a Lua function | `string(obj.code)` | `tostring(obj.code)` | ✅ Test confirms `string()` would error |
| Timeout operator precedence | `a and b == "number" or c > 0` | `a and (b == "number" and c > 0)` | ✅ Test confirms original crashes with string input |
| Timeout unit mismatch | `timeout = 3` (seconds) with `vim.defer_fn` (ms) | `timeout = 3000` (ms) | ✅ Consistent ms units |
| `vim.log.level.INFO` typo | Missing 's' | `vim.log.levels.INFO` | ✅ Test confirms `vim.log.level` is nil |
| venv-selector hard dependency | `require('venv-selector')` | `pcall(require, 'venv-selector')` | ✅ No crash without plugin |
| `_current_runner` race condition | Kill in async callback | Kill before starting new runner | ✅ Test confirms PID changes |

### PR Branch
`feat/nvim-runner-plugin` on `Kailian-Jacy/nvim-config`
