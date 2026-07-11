# sidekick.nvim (Copilot Next Edit Suggestions) — integration & investigation

## Goal

Add [folke/sidekick.nvim](https://github.com/folke/sidekick.nvim) for Copilot
**Next Edit Suggestions (NES)** alongside the existing `copilot.vim` inline
completion. NES is complementary to inline completion, not a replacement:

| | Inline completion (copilot.vim) | NES (sidekick.nvim) |
|---|---|---|
| Where | insert mode, ghost text at cursor | normal mode, diff/edit anywhere in file |
| When | as you type | after you *finish* an edit that implies a follow-up |
| Trigger events | insert | `ModeChanged i:n`, `TextChanged`; cleared on `InsertEnter`/`TextChangedI` |

## Keymap design (normal mode)

NES lives in normal mode (it is cleared on `InsertEnter`/`TextChangedI`), so the
maps are normal-mode only, in `lua/config/keymaps.lua`:

- **`<Tab>`** — if a suggestion is pending, `nes_jump_or_apply()` (jump, then
  apply on the next press); otherwise `require("sidekick.nes").update()`
  (request one now). Replaces the rarely-used `FlipPinnedTab` and the
  treesitter incremental-selection `<Tab>` (removed from `plugins/lsp.lua`).
- **`<Esc>`** — layered: first press dismisses a pending suggestion
  (`nes.clear()`), otherwise falls back to the original `:noh` behavior.
  `nes.clear.esc = false` is set so this map is the sole `<Esc>` handler.

Both maps are `pcall`-guarded, so they are safe no-ops if sidekick is absent.

## LSP wiring — what changed and why

sidekick is only an *NES client*; it needs a `copilot-language-server` LSP
client attached. Key finding during integration:

- **`copilot.vim` already starts its own `vim.lsp` client named
  `"GitHub Copilot"`** (`autoload/copilot/client.vim` →
  `_copilot.lsp_start_client` → `vim.lsp.start`).
- sidekick's `require("sidekick.config").is_copilot()` matches any client whose
  name contains `copilot` (case-insensitive), so it uses copilot.vim's client
  automatically.
- An earlier attempt registered a **second, dedicated** `copilot` client via
  `vim.lsp.config`/manual attach. This was redundant and created a
  duplicate-client hazard (`get_client()[1]` becomes ambiguous), so it was
  removed. `plugins/lsp.lua` now just documents that copilot.vim provides the
  client; auth is via `:Copilot setup`.

Notes for other setups:
- `vim.lsp.enable("copilot")` only auto-attaches a config that declares
  `filetypes`; the canonical `lsp/copilot.lua` omits them, so a bare `enable()`
  never attaches — you must drive attachment yourself or list filetypes.
- Older `nvim-lspconfig` pins predate `lsp/copilot.lua` (added 2025-08), so
  `vim.lsp.enable("copilot")` warns "config not found" there.

## NES returns no suggestions — root-cause investigation

Symptom: everything loads, `:Copilot status = Ready`, inline completion works,
but `require("sidekick.nes").have()` is always `false` and `<Tab>` does nothing.

To settle it, the sandbox Copilot was authenticated (device flow) and
`textDocument/copilotInlineEdit` was exercised directly. Findings:

| Layer | Result |
|---|---|
| Auth | signed in |
| Network / API | inline completion returns items (API reachable) |
| NES feature flag | server sends `ide_enable_copilot_nes_nonfree_enabled = true` |
| LSP client attaches, sidekick matches it | yes |
| Request shape (matches copilot-lsp & sidekick exactly) | yes |
| `textDocument/copilotInlineEdit` result | **`edits: []` (empty), `err = nil`** |

The empty NES result reproduced across **all** of the following, i.e. it is not
a config variable:

- copilot.vim's `"GitHub Copilot"` client **and** a dedicated client on the
  latest standalone `copilot-language-server` (1.519/1.520);
- `context.triggerKind` = none / 1 / 2, with and without a `context` field;
- `settings.github.copilot.nextEditSuggestions.enabled = true` +
  `workspace/didChangeConfiguration`;
- **real typed edits** (`ciw` rename generating genuine `didChange`), polled
  6× over ~9s;
- `didFocus` sent before the request (required by the protocol);
- editor identity `editorInfo`/`editorPluginInfo` = `Neovim` / `vscode` /
  `copilot.vim`.

### Conclusion

The Neovim / sidekick / copilot **configuration is correct and complete**.
`have() == false` faithfully reflects that the Copilot backend returns **no**
Next-Edit for this account/context — despite `inlineCompletion` working and the
NES feature flag being enabled. This is **server-side**, outside Neovim's
control.

### Suggested follow-up (server-side)

1. Reproduce NES in **VS Code** with the same account:
   - also empty → account/plan/policy/rollout issue (check
     `github.com/settings/copilot`, org Copilot policy; the `nonfree` flag hints
     at an entitlement nuance) — raise with GitHub if needed;
   - works in VS Code but not Neovim → a protocol delta worth diffing the raw
     `copilotInlineEdit` payloads.
2. Nothing further is required on the Neovim side; when the backend starts
   returning edits, sidekick surfaces them automatically via the existing
   `<Tab>`/`<Esc>` maps.

## Files changed

- `lua/config/keymaps.lua` — normal-mode `<Tab>`/`<Esc>` NES maps.
- `lua/plugins/ai.lua` — `folke/sidekick.nvim` spec (NES only, `clear.esc=false`).
- `lua/plugins/lsp.lua` — removed treesitter incremental-selection `<Tab>`/
  `<S-Tab>`; documented that copilot.vim supplies the LSP client.
- `lazy-lock.json` — pin `sidekick.nvim`.
