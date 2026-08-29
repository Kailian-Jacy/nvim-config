# dsh.nvim

The DeepSeek Harness ⇄ neovim bridge. Its first feature is `walkthrough`: a
guided, annotated code tour that an agent authors as data and drives over the
RPC socket, while the human reads it and navigates with keys.

## Why data, not code

A walkthrough is a **deck**: a JSON file describing steps, prose and code
annotations. Decks are passed by **path**, never inline, because quoting a large
payload through `--remote-expr` is a reliable source of breakage.

The plugin never writes to the files it annotates. Every code decoration is an
extmark (`virt_lines`, `virt_text`, `sign_text`, `line_hl_group`), which is
display-only buffer metadata: `'modified'` stays off, `nvim_buf_get_lines`
returns byte-identical content, and closing clears the namespace.

## Layout

```
lua/dsh/init.lua                 setup + lazy submodule access
lua/dsh/walkthrough/init.lua     session state and the public API
lua/dsh/walkthrough/config.lua   defaults, derived width limits
lua/dsh/walkthrough/deck.lua     JSON load, normalise, VALIDATE
lua/dsh/walkthrough/panel.lua    storyline sidebar rendering
lua/dsh/walkthrough/annotate.lua extmark code decoration
lua/dsh/walkthrough/text.lua     wrapping + a small code tokenizer
lua/dsh/walkthrough/hl.lua       theme-derived highlight groups
plugin/dsh.lua                   :Walkthrough* commands
```

## API

Each function returns a short human-readable string, so a caller can read the
result without decoding JSON.

| call | effect |
| --- | --- |
| `require("dsh.walkthrough").limits()` | JSON of the authoring limits |
| `.validate(path, strict)` | report problems, no UI |
| `.open(path, {force=true})` | validate then open; refuses a broken deck |
| `.reload()` | re-read the deck file, keep position |
| `.next()` / `.prev()` / `.goto_step(n)` | navigate |
| `.layer(n?)` | cycle or set disclosure layer |
| `.status()` | one-line state |
| `.state()` | full JSON state |
| `.close()` | clear annotations, restore keymaps |

Commands: `:WalkthroughOpen[!] {file}`, `:WalkthroughValidate {file}`,
`:Walkthrough [n]`, `:WalkthroughLayer [n]`, `:WalkthroughReload`,
`:WalkthroughClose`.

## Deck schema

```jsonc
{
  "title": "lazy.nvim · how lazy loading works",
  "root": "/abs/dir",                     // optional: tcd for the new tab
  "roots": [{ "dir": "/abs/prefix", "label": "short" }], // optional path shortening
  "steps": [
    {
      "act":   "ACT I · SPEC → FRAGMENTS", // optional group heading
      "title": "Entry: Plugin.load()",
      "file":  "/abs/path/plugin.lua",
      "lnum":  322,                        // cursor line
      "range": [322, 346],                 // tinted region
      "brief": "one line, shown for every step in BRIEF",
      "body":  "short summary, shown on focus in OUTLINE",
      "detail": [                          // shown on focus in BRIEF
        { "h": "THE IDEA", "t": "prose ..." },
        { "h": "IN CODE",  "c": "pseudo code\nsecond line" }
      ],
      "ann": [                             // inline code annotations
        { "pat": "local specs = {", "kind": "eol",  "text": "built here" },
        { "pat": "plugin._.loaded", "kind": "note", "text": "longer aside" }
      ]
    }
  ]
}
```

`pat` is a **literal substring**, resolved at display time within `range` and
falling back to the whole file. Anchoring by content rather than line number
means a deck keeps pointing at the right statement when the file shifts.

## Layers

`OUTLINE` shows titles plus the focused step's `body`. `BRIEF` adds a one-line
`brief` under every step and renders the focused step's `detail` sections. Detail
is always scoped to the focused step — there is deliberately no
expand-everything layer, because that produces an unreadable wall of text.
