# nvim-runner

A Neovim plugin for running scripts directly from your buffer. Supports Python, Lua, Shell, and Nushell with async execution, timeout control, and buffer-local runner overrides.

## Features

- **Multi-language**: Python, Lua (in-process), Shell (zsh/bash), Nushell
- **Async execution**: Non-blocking with `vim.system`, results inserted at cursor
- **Timeout**: Configurable per-runner, per-buffer, or global timeout (kills runaway processes)
- **Visual mode**: Run selected text instead of entire buffer
- **Buffer-local runners**: Override runners per-buffer with `SetBufRunner` or `vim.b.runner`
- **Test runner**: Discover and run `*_vimtest.lua` files in cwd

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Kailian-Jacy/nvim-runner",
  config = function()
    require("nvim-runner").setup()
  end,
}
```

Or for local development:

```lua
{
  dir = "~/path/to/nvim-runner",
  config = function()
    require("nvim-runner").setup()
  end,
}
```

## Configuration

```lua
require("nvim-runner").setup({
  runners = {
    python = {
      runner = function() ... end,  -- returns interpreter path
      template = "echo -e | ${runner} <<EOF\n${text}\nEOF",
      timeout = 3000,  -- ms
    },
    nu = {
      runner = "nu",
      template = "...",
      timeout = 5000,
    },
    lua = {
      runner = "this_neovim",  -- special: runs inside neovim
      template = "${text}",
    },
    sh = {
      runner = "zsh",
      template = "${text}",
    },
  },
  timeout = 3000,        -- default timeout in ms
  insert_result = true,  -- insert output at cursor position
  keymaps = {
    run = { "<c-s-cr>", "<d-s-cr>" },
  },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:RunScript` | Run current buffer or visual selection |
| `:RunTest` | Run all `*_vimtest.lua` files in cwd |
| `:SetBufRunner {template}` | Set a buffer-local runner template |
| `:RunnerTimeout {ms}` | Set buffer-local timeout (e.g., `:RunnerTimeout 5000`) |
| `:RunnerTimeout! {ms}` | Set global timeout (e.g., `:RunnerTimeout! 10000`) |

## Usage

1. Open a `.py`, `.lua`, `.sh`, or `.nu` file
2. Press `<Ctrl-Shift-Enter>` (or your configured keymap)
3. Output is inserted below the cursor

### Visual Mode

Select some lines, then run — only the selection is executed.

## Template System

Templates define how your code is executed. They use two placeholders:

- **`${runner}`** — Replaced with the resolved runner executable path (e.g., `python3`, `zsh`, `nu`)
- **`${text}`** — Replaced with the buffer content (or visual selection)

### How Templates Work

When you run `:RunScript`, nvim-runner:

1. Resolves the `runner` field to get the executable (can be a string or function)
2. Gets the `text` from the buffer or visual selection
3. Replaces `${runner}` and `${text}` in the template string
4. Executes the resulting command via `vim.system`

### Heredoc Templates

For languages like Python and Nushell, the template uses a shell heredoc to pass multi-line code via stdin. This avoids issues with quoting and escaping:

```
echo -e | ${runner} <<EOF
${text}
EOF
```

This pipes the buffer content into the interpreter as a heredoc, so the code doesn't need to be escaped for shell.

### Template Examples

#### Example 1: Run Python with a specific interpreter

```lua
require("nvim-runner").setup({
  runners = {
    python = {
      runner = "/usr/bin/python3.11",
      template = "echo -e | ${runner} <<EOF\n${text}\nEOF",
      timeout = 5000,
    },
  },
})
```

#### Example 2: Run TypeScript with ts-node

```lua
require("nvim-runner").setup({
  runners = {
    typescript = {
      runner = "npx ts-node",
      template = "${runner} -e '${text}'",
      timeout = 10000,
    },
  },
})
```

#### Example 3: Run Ruby code

```lua
require("nvim-runner").setup({
  runners = {
    ruby = {
      runner = "ruby",
      template = "${runner} <<'RUBY'\n${text}\nRUBY",
      timeout = 5000,
    },
  },
})
```

#### Example 4: Run Go with `go run` (using a temp file approach via function template)

```lua
require("nvim-runner").setup({
  runners = {
    go = {
      runner = "go",
      template = function(runner, text)
        -- Write to temp file and run
        local tmpfile = vim.fn.tempname() .. ".go"
        local f = io.open(tmpfile, "w")
        f:write(text)
        f:close()
        return runner .. " run " .. tmpfile
      end,
    },
  },
})
```

#### Example 5: Direct shell execution (no runner needed)

```lua
require("nvim-runner").setup({
  runners = {
    sh = {
      runner = "zsh",    -- or "bash"
      template = "${text}",  -- text IS the command
    },
  },
})
```

Here `${runner}` is not used in the template — the text itself is the shell command.

### Buffer-local Runner Override

Use `:SetBufRunner` to temporarily override the runner for the current buffer:

```vim
" Use a specific Python version for this buffer
:SetBufRunner echo -e | /usr/local/bin/python3.12 <<EOF\n${text}\nEOF

" Use docker to run the code
:SetBufRunner docker run --rm -i python:3.12 python3 <<EOF\n${text}\nEOF
```

Or set it via Lua:

```lua
vim.b.runner = {
  python = {
    runner = "/path/to/special/python",
    template = "echo -e | ${runner} <<EOF\n${text}\nEOF",
  },
}
```

**Use cases for buffer-local runners:**
- Testing with a different interpreter version
- Running code inside a Docker container
- Using a project-specific virtual environment
- Temporarily changing timeout for a long-running script
- Experimenting with different execution strategies

### Adding a New Language Runner in `setup()`

To add support for a new language, define its `runner` and `template` in the `runners` table:

```lua
require("nvim-runner").setup({
  runners = {
    -- Rust via cargo-script
    rust = {
      runner = "rust-script",
      template = "${runner} <<'EOF'\n${text}\nEOF",
      timeout = 15000,
    },
    -- Perl
    perl = {
      runner = "perl",
      template = "${runner} -e '${text}'",
      timeout = 3000,
    },
    -- JavaScript via Node.js
    javascript = {
      runner = "node",
      template = "${runner} <<'EOF'\n${text}\nEOF",
      timeout = 5000,
    },
  },
})
```

The key in the `runners` table must match the Neovim filetype (`:echo &filetype`).

## Timeout

Timeout controls how long a script can run before being killed. The priority is:

```
buffer-local timeout > runner-defined timeout > setup() global timeout > default 3000ms
```

### Setting Timeout

```lua
-- In setup()
require("nvim-runner").setup({ timeout = 5000 })

-- Programmatically (global)
require("nvim-runner").set_timeout(10000)

-- Programmatically (buffer-local)
require("nvim-runner").set_buf_timeout(0, 5000)  -- 0 = current buffer

-- Via vim.b variable
vim.b.runner_timeout = 8000
```

### Timeout Commands

```vim
" Set timeout for current buffer only
:RunnerTimeout 5000

" Set global timeout (with bang)
:RunnerTimeout! 10000
```

## Running Tests

```sh
cd nvim-runner

# Main test suite
nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_runner_spec.lua"

# Fix-specific tests (keymap dedup, buffer validity, timeout API)
nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_fixes_spec.lua"

# String.gsub special character tests
nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_gsub_special_chars.lua"
```

## License

MIT
