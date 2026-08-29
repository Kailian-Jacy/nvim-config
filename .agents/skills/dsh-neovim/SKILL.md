---
name: dsh-neovim
description: Present a guided, annotated code walkthrough inside the user's running neovim by driving the dsh.nvim walkthrough engine over its RPC socket. Use ONLY when the user explicitly asks for a walkthrough, code tour, guided read-through, or "walk me through X in my neovim", or explicitly hands over the neovim socket for that purpose. Covers socket discovery, deck authoring limits, validation before display, navigation, and the safety rules for annotating files you must not modify.
---

# Presenting a code walkthrough in the user's neovim

Explain code where the code lives: a narrow storyline panel on the left, the real
source on the right, annotated in place. The engine is `dsh.nvim`
(`<config>/plugins/dsh.nvim`); you supply content as data and drive navigation
over the socket.

## Use this only when asked

Invoke this skill when the user explicitly asks for a walkthrough in their editor
— "walk me through X in my neovim", "give me a guided tour of this module",
"show me this in nvim" — or explicitly gives you the socket to do it.

Do **not** reach for it to answer an ordinary question about code. A chat answer
with a couple of quoted snippets is almost always the right response; a
walkthrough takes over a tab, rebinds keys and annotates buffers, so it needs the
user's intent behind it. If you are unsure whether they want the editor driven,
ask before touching the socket.

## What the reader gets

Two disclosure layers, toggled with `<space>qi`. Detail is always scoped to the
focused step; there is no expand-everything mode, because that is an unreadable
wall of text.

- **OUTLINE** — every step title, plus the focused step's `body` (1–3 sentences).
- **BRIEF** — a one-line `brief` under every step, plus the focused step's
  `detail`: titled sections of prose and code.

`<space>qj` / `<space>qk` step forward and back, `<CR>` in the panel jumps to the
step under the cursor. Those keys are saved and restored on close.

## Interaction flow

1. **Confirm the request is explicit.** See above.
2. **Resolve the socket.** `scripts/wt socket`, or set `NVIM_SOCKET`. The helper
   picks the newest socket under the per-user runtime dir.
3. **Query the limits — never assume them.** `scripts/wt limits` returns
   `max_code_width`, `max_prose_width` and the layer names for the *user's*
   configured panel width. Authoring against a guessed width causes truncation.
4. **Read the real code first.** Every claim must come from the file you are
   pointing at. Where the behaviour is observable, verify it live rather than
   asserting it — a traced result is worth more than a confident paragraph.
5. **Write the deck to a file**, then `scripts/wt validate deck.json`.
6. **Fix every problem before displaying anything.** `open` refuses a deck with
   structural problems by design.
7. **Open it:** `scripts/wt open deck.json`. Then hand over: tell the user the
   keys, and summarise in chat what the walkthrough argues — do not paste the
   whole content back at them.
8. **Respond to follow-ups** by editing the deck and `scripts/wt reload`, or by
   navigating with `goto`/`layer`.
9. **`scripts/wt close`** when they are done. It clears annotations, unlocks
   buffers and restores keymaps.

## Deck shape

See `scripts/example-deck.json` for a complete two-step deck. Fields:

| field | role |
| --- | --- |
| `title` | panel header |
| `root` | optional; `tcd` for the walkthrough's tab |
| `roots[]` | optional `{dir,label}` pairs that shorten displayed paths |
| `steps[].act` | group heading; steps sharing one act render under it |
| `steps[].title` | step name; prefix `★` for the pivotal ones |
| `steps[].file` `lnum` `range` | absolute path, cursor line, tinted line range |
| `steps[].brief` | one line, shown for every step in BRIEF |
| `steps[].body` | short summary, shown on focus in OUTLINE |
| `steps[].detail[]` | `{h, t}` prose or `{h, c}` code — never both in one |
| `steps[].ann[]` | `{pat, kind, text}` inline code annotations |

`pat` is a **literal substring**, resolved at display time inside `range` and
falling back to the whole file. Anchor by content, never by line number: the deck
then keeps pointing at the right statement when the file shifts, and the
validator tells you when an anchor stops matching.

## Getting the length and focus right

This is where a walkthrough succeeds or fails. Aim for something a person will
actually read.

**Shape.** 15–35 steps, grouped into 3–5 acts of 5–10 steps. One idea per step.
If a step needs two code blocks to explain two mechanisms, it is two steps.

**Per step.**

| part | budget | notes |
| --- | --- | --- |
| `title` | ≤ 44 cols | a claim, not a label: "★ The recursion guard" |
| `brief` | one line, ≤ `max_prose_width` | the takeaway, no trailing period needed |
| `body` | 1–3 sentences | what this code does |
| `detail` | 3–5 sections | at least one must be code |
| prose section | 2–4 sentences | one point per section |
| code section | 5–12 lines, ≤ `max_code_width` | pseudo-code, not a copy |
| `ann` | 3–7 per step | see below |

**Section headings** are short and ALL CAPS. Prefer a small, repeating
vocabulary so the reader learns the rhythm: `THE IDEA`, `IN CODE`,
`WHY IT MATTERS`, `THE MECHANISM`, `THE TRADE-OFF`, `CONSEQUENCE`, `THE TRAP`,
`LIVE STATE`, `SIDE BY SIDE`.

**Code sections are illustrations, not excerpts.** The real code is already on
screen to the right. Compress it to the shape of the logic — drop error handling
and logging, keep the ordering that matters, and use `-->` arrows for results.
A second code section showing a concrete before/after or a live trace usually
teaches more than another paragraph.

**Annotations carry the pointing.** `eol` for a short pointer on the lines that
matter (≤ ~45 chars, one clause). `note` for the one or two genuinely subtle
places per walkthrough — it injects a wrapped block above the line, so it is
expensive screen space. A step with seven `note`s is a step nobody reads.

**Ground it in the user's own code.** A walkthrough of a library is far stronger
when several steps point at the reader's own config or call sites and show real
values from their session. Say what you observed, and label it: `LIVE STATE`.

**Mark the spine.** Prefix the 4–8 steps that carry the core argument with `★`.
They render in an accent colour, so a reader who only follows the stars still
gets the thesis.

## Safety rules

**Never modify the files you are explaining.** The engine only decorates:
`virt_lines`, `virt_text`, `sign_text` and `line_hl_group` are display-only
buffer metadata, so `'modified'` stays off and the bytes on disk are untouched.
Do not "fix" code you are documenting.

**Source buffers are locked `nomodifiable`** while a walkthrough owns them
(`readonly_source`), and restored on `close`. Leave that on. A walkthrough parks
the cursor in someone else's installed plugin; with an autosave plugin active a
single stray keystroke is written to disk and the `modified` flag clears itself,
which makes the damage silent.

**Verify with version control, not `&modified`.** To claim files are untouched,
run `git -C <repo> diff --stat` on the annotated repository. `&modified` is
worthless as evidence when autosave is in play, because saving is exactly what
clears it.

**Do not rearrange the user's windows.** The engine opens its own tab and cleans
up after itself. Never run `:only`, never close windows you did not create, and
never assume the tab you want is the current one.

**Leave the instance as you found it.** `close` restores keymaps, unlocks
buffers and clears every extmark namespace it created.

## Cookbook

```bash
S=.agents/skills/dsh-neovim/scripts
$S/wt socket                     # resolve and print the socket
$S/wt limits                     # {"max_code_width":50,"max_prose_width":52,...}
$S/wt validate deck.json         # fix everything it reports first
$S/wt open deck.json             # validates, then opens in its own tab
$S/wt goto 12 ; $S/wt layer 2    # drive it for the user
$S/wt state                      # full JSON: idx, total, unresolved, titles
$S/wt reload                     # after editing deck.json
$S/wt close                      # restore keymaps, unlock, clear annotations
```

Inside neovim the same surface is available as `:WalkthroughOpen`,
`:WalkthroughValidate`, `:Walkthrough [n]`, `:WalkthroughLayer [n]`,
`:WalkthroughReload` and `:WalkthroughClose`.

## Failure modes

| symptom | cause and fix |
| --- | --- |
| `REFUSED: deck has N problem(s)` | structural errors; fix them, do not pass `force` |
| `UNRESOLVED anchor "..."` | `pat` no longer matches; pick a distinctive substring from the current file |
| anchor resolves outside `range` | widen `range`, or choose a pattern inside it |
| `code line N cols > M max` | shorten the line; the panel would truncate it |
| panel text looks dim and hard to read | you put prose in a code section, or vice versa |
| nothing happens on a call | plugin not loaded yet; any `require("dsh.walkthrough")` triggers lazy.nvim's module searcher and loads it |
| `--remote-expr` quoting errors | never inline a payload; write a file and `loadfile` it, as `scripts/wt` does |
