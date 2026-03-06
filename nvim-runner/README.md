# nvim-runner

A Neovim plugin for running scripts directly from your buffer. Supports Python, Lua, Shell, and Nushell with async execution, timeout control, and buffer-local runner overrides.

## Features

- **Multi-language**: Python, Lua (in-process), Shell (zsh/bash), Nushell
- **Async execution**: Non-blocking with `vim.system`, results inserted at cursor
- **Timeout**: Configurable per-runner or global timeout (kills runaway processes)
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

## Usage

1. Open a `.py`, `.lua`, `.sh`, or `.nu` file
2. Press `<Ctrl-Shift-Enter>` (or your configured keymap)
3. Output is inserted below the cursor

### Visual Mode

Select some lines, then run — only the selection is executed.

### Buffer-local Override

```vim
:SetBufRunner echo -e | /usr/bin/python3 <<EOF\n${text}\nEOF
```

Or in Lua:

```lua
vim.b.runner = {
  python = {
    runner = "/path/to/python",
    template = "echo -e | ${runner} <<EOF\n${text}\nEOF",
  }
}
```

## Running Tests

```sh
cd nvim-runner
nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_runner_spec.lua"
```

## License

MIT
