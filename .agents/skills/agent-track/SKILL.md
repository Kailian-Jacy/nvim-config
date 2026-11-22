---
name: agent-track
description: "Stream atomic shadow-ref subcommits while coding so a human can live-review in Neovim (codediff.nvim) in causal Touch-Order, cherry-sync approved slices fail-fast without touching .git/index, or steer via review notes — finalizing into clean git commits via walk-commit. Compatible with any agent harness (dsh, Claude Code, Antigravity, Codex)."
---

# agent-track

Stream incremental, reviewable checkpoints (`subcommit`s) onto shadow Git refs (`refs/subcommits/<session>/agent`) **while** working in a single-writer agent workflow, keeping `HEAD` and `.git/index` completely untouched until final branch commits.

```bash
AT="<repo>/.agents/skills/agent-track/scripts/agent_track.py"
```

## 1. Agent Workflow (Inside Agent Replica `R`)

### Step 1 — Bootstrap Session Once
```bash
$AT init-agent [--session default] [--base HEAD]
```
Records `refs/subcommits/<S>/base` and initializes `refs/subcommits/<S>/agent` with reflog `.git/logs/refs/subcommits/<S>/agent` so local `fs_event` or remote SSH `tail -F` watchers in the human's Neovim (`L`) wake immediately.

### Step 2 — Emit Atomic Shadow Subcommits After Cohesive Slices
Whenever one coherent micro-step compiles/passes (e.g. a type/interface addition, one module's logic, a test slice):
```bash
$AT subcommit \
  -m "scheduler: add retry policy types and backoff math" \
  --why "Isolate pure retry calculation before wiring DAO call sites" \
  --files src/retry.lua,tests/retry_spec.lua \
  --order src/retry.lua,tests/retry_spec.lua
```

**Discipline & Guardrails**
- **Shadow-only by default** (`--branch-mode=shadow`): builds commits in a temporary `GIT_INDEX_FILE` (`git read-tree` -> `git add -A` -> `git write-tree` -> `git commit-tree` -> `git update-ref`). Never run `git commit` for intermediate checkpoints unless explicitly asked.
- **Keep slices small**: target **<= 5 files** and **<= 150 changed lines** per subcommit. Larger diffs trigger a coaching warning on `stderr` (or hard-fail under `--strict`). Use `--files f1,f2` when your working tree holds edits for more than one logical step.
- **Causal `--order` (`Touch-Order` trailer)**: list paths in the order a human brain should read them — **contract/types -> core mechanism -> call sites -> tests/wiring** — never alphabetical dump. The human steps through files in Neovim with `]f` / `[f` in this exact sequence.
- **One-sentence `-m`**: imperative, concrete (`module: verb what changed`), `<= 72` chars. Put non-obvious rationale in `--why`.

### Step 3 — Act on Human Review Notes (`inbox`)
Every `subcommit` automatically checks `inbox` and alerts on `stderr` if the human rejected a slice. Check explicitly anytime:
```bash
$AT inbox [--session default] [--json]
```
- **Single-writer model**: the agent is the code writer in `R`; the human reviews in Neovim (`approve` / `reject` notes + harness prompts) and fail-fast syncs approved slices into `L`.
- **Handling `rejected` notes**:
  - Inspect `comment` and `subcommit_id` in `inbox --json`.
  - Either emit a corrective follow-up `subcommit`, amend the tip (`$AT subcommit --amend -m "..."`), or rewrite the chain (`--parent <sha>`) preserving `--id <sc-...>`:
    - Unchanged patches (`git patch-id --stable` match) automatically **retain** `approved` / `rejected` across rewrites.
    - Modified patches on a previously `approved` `Subcommit-Id` automatically transition to `stale` so the human re-verifies only what changed.
- **Approved with a comment** (`<leader>tc` in Neovim): `status` is `approved` and `comment` holds a non-blocking suggestion; fold it into later slices or mention it in the hand-off, and don't block on it.
- **Reviewing an existing MR/PR instead of live work?** Use the `agent-track-mr` skill: it replays the MR as session `mr-<N>` and prints the `:AgentTrack attach ssh://<host>/<repo> mr-<N>` command.

### Step 4 — Finalize Clean Branch Commits (`walk-commit` Synergy)
Because shadow mode never touched `refs/heads/<branch>` or `.git/index`:
1. Once all work is complete and verified, review `git status` / `git diff --stat` in `R`.
2. Follow **`.agents/skills/walk-commit/SKILL.md` Part A** to create clean, single-purpose Git commits on the real branch (splitting refactors, core features, and wiring cleanly; always pass `-c commit.gpgsign=false` in headless shells).
3. If the user asks to walk final commits in Neovim, use `walk-commit` Part B (`walk_commit.py`).

## 2. Driving Human Neovim via `:GrantSocket` (Host Helpers)

When run on the human host with `:GrantSocket` active (`/tmp/nvim-$USER/nvim-*.sock`), host subcommands dispatch over RPC (`require("agent-track").rpc.dispatch`), falling back to pure Git when `--no-nvim` is passed or no socket is active:

```bash
$AT attach <path_or_ssh_url> [--session S]   # bind L to R (local path or user@host:/path) & start watcher
$AT fetch                                    # fetch agent + base + notes refs from R
$AT list [--json]                            # list subcommits with review/sync status
$AT open [idx|sha|sc-id]                     # open subcommit in reused [track] :CodeDiff tab
$AT approve [idx|sha] [--prefix]             # approve single subcommit (note) or 1..k watermark (--prefix)
$AT reject <idx|sha> -m "<reason>"           # reject with note comment & push notes to R
$AT sync [approved|all|idx|sha]              # fail-fast 3-way merge into L (never touches .git/index or writes markers)
$AT undo                                     # lossless pop from refs/subcommits/<S>/undo stack
$AT clean [--session S]                      # delete session refs & notes
```
