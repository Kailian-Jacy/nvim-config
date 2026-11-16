# agent-track

Single-writer subcommit streaming, causal `codediff.nvim` review, and fail-fast non-intrusive working-tree sync between a human's Neovim (`L`) and any local or remote SSH agent replica (`R`) — built directly on Git 2.38+ plumbing with **zero intermediary server** (no GitLab/GitHub round-trip), **zero `.git/index` or `HEAD` mutation**, and **zero conflict markers written to `L`**.

---

## 1. Topology & Single-Writer Streaming Architecture

```mermaid
flowchart LR
  subgraph R["Agent Replica R (Single Code Writer)"]
    WT_R["Agent Worktree"] -->|"agent_track.py subcommit (temp GIT_INDEX_FILE)"| REF_A["refs/subcommits/S/agent + reflog"]
    REF_N_R["refs/notes/subcommits/S"] -->|"agent_track.py inbox"| WT_R
  end
  subgraph L["Human Host L (Neovim + codediff.nvim)"]
    WATCH["watch.lua (fs_event / ssh tail -F)"] -->|"git fetch +refs/subcommits/..."| REF_L["Local Shadow Refs"]
    REF_L --> REV["reviewer.lua (Snacks.picker + [track] CodeDiff)"]
    REV -->|"git push notes / approved"| REF_N_R
    REF_L -->|"sync.lua (fail-fast merge-tree + checkout-index)"| WT_L["Human Buffers (.git/index untouched)"]
  end
  REF_A -.->|"inotify/kqueue or outbound SSH"| WATCH
```

- **Local Mode (`:AgentTrack attach /path/to/R`)**: watches `<R-git-common-dir>/logs/refs/subcommits/<S>/agent` via `vim.uv.new_fs_event` (+ `poll_ms` fallback) and runs debounced async `git fetch`.
- **Outbound SSH Mode (`:AgentTrack attach user@devbox:/path/to/R` or `ssh://...`)**: `L` opens one multiplexed outbound `ssh` stream (`ControlMaster=auto`) resolving `git rev-parse --git-common-dir` (supporting standard repos, Git worktrees, and bare repos) and running `tail -n0 -F "$d/logs/refs/subcommits/<S>/agent"` with `ssh_poll_ms = 0` and fast-failure circuit-breaker backoff. `R` never needs inbound network access, credentials, or a central Git server back to `L`.

---

## 2. Git Ref, Note & Trailer Protocol

All session state lives under `<ref_prefix>/<session>/` (default `refs/subcommits/default/`) plus `refs/notes/<notes_prefix>/<session>` (`refs/notes/subcommits/default`):

| Ref / Note | Object | Purpose |
| :--- | :--- | :--- |
| `base` | Commit | Common ancestor SHA at `init-agent`. |
| `agent` | Commit | Agent's latest shadow subcommit tip (linear chain `base..agent`, reflog enabled). |
| `synced` | Commit | Exact agent tree merged into `L` so far (`base` initially; synthetic `commit-tree` with `Applied-Subcommits` trailer on cherry sync). |
| `approved` | Commit | Optional prefix-approval watermark (`1..k`). |
| `undo` | Commit | Lossless `commit-tree` stack of pre-sync `L` working trees (`Restores-Synced`, `Restores-Applied` trailers). |
| `state` | Blob | JSON `{ remote, session, applied_ids }`. |
| `refs/notes/subcommits/<S>` | Notes | Per-commit JSON `{"status":"approved"\|"rejected"\|"pending","comment":"...","subcommit_id":"...","patch_id":"<git patch-id --stable>","updated_at":<unix>}`. |

**Subcommit Commit Trailers**
- `Subcommit-Id: sc-YYYYMMDDHHMMSS-xxxx` — stable logical identity across history rewrites.
- `Touch-Order: path/a.lua, path/b.lua` — causal reading sequence stepped by `]f` / `[f`.

**Effective Review Status Precedence (`list()`)**
1. Direct note on `<sha>` (`review_via = "note"`).
2. Orphan note matching `Subcommit-Id` across rewrite (`review_via = "rewrite"`): if `patch_id` matches `git patch-id --stable`, preserves status; if `patch_id` changed on a previously `approved` subcommit, marks `"stale"`.
3. Ancestor of `refs/subcommits/<S>/approved` (`review_via = "prefix"`).
4. Otherwise `"pending"`.

**Git Safety Invariants**: Every commit/note/ref write passes `-c commit.gpgsign=false` (prevents headless SSH/GPG signer hangs, including on `git notes add`), fallback `-c user.name=agent-track -c user.email=agent-track@local` when unset, and `-c core.logAllRefUpdates=always`.

---

## 3. Fail-Fast Non-Intrusive Sync & Undo

1. **`.git/index` & `HEAD` Invariance**: `apply()` and `undo()` copy `.git/index` to a temporary `GIT_INDEX_FILE`, stage modified tracked files + only untracked paths touched by `diff-tree(base, target)`, run `git merge-tree --write-tree -z` in memory, push pre-sync `L` onto `refs/subcommits/<S>/undo`, and materialize only changed files via `git checkout-index -f` + `silent! checktime`. Staged index entries, `HEAD`, and unrelated untracked files remain byte-for-byte untouched.
2. **Non-Prefix Cherry Sync (`:AgentTrack sync approved`)**: When subcommits `#1` and `#3` are approved while `#2` is rejected, `sync.lua` folds each unapplied approved `S_i` onto `synced` via `git merge-tree --write-tree --merge-base=parent(S_i) <acc_tree> <S_i>`, then 3-way merges the resulting tree into `L`.
3. **Fail-Fast Clean Merge Guarantee**: `list()` previews overlapping local edits with a `⚡` (`would_conflict`) badge. If `apply()` detects a conflict (`not merged.clean`), it **aborts before writing anything to disk or touching `undo`**, returning `{ ok = false, conflict = true, conflicts = ... }` — never polluting `L` with `<<<<<<<` conflict markers. In this single-writer design, the human steers direction via `approve` / `reject` notes and harness prompts while keeping `L` clean.

---

## 4. Configuration (`setup(opts)`)

```lua
require("agent-track").setup({
  ref_prefix = "refs/subcommits",
  notes_prefix = "subcommits",
  default_session = "default",
  git_cmd = { "git" },
  ssh_cmd = {
    "ssh", "-o", "BatchMode=yes",
    "-o", "ControlMaster=auto", "-o", "ControlPath=/tmp/at-ssh-%C",
    "-o", "ControlPersist=600", "-o", "ServerAliveInterval=30",
  },
  watch = {
    enabled = true,
    mode = "auto",          -- "auto" | "local" | "ssh" | "poll"
    poll_ms = 5000,         -- fallback poll interval for local/poll modes
    ssh_poll_ms = 0,        -- 0 disables periodic git fetch polling over SSH
    debounce_ms = 150,
    reconnect_ms = 3000,
    max_retries = 3,        -- fast-failure circuit breaker before detaching SSH watcher
    remote_tail_cmd = nil,  -- optional custom argv override for SSH tail
  },
  auto_save_before_sync = true,
  auto_sync_approved = false,
  notify_on_arrival = true,
  reviewer = {
    tab_prefix = "[track]",
    reuse_tab = true,
    keymaps = {
      next_subcommit = "]c",
      prev_subcommit = "[c",
      next_touch_file = "]f",
      prev_touch_file = "[f",
      approve = "<leader>ta",
      approve_prefix = "<leader>tA",
      reject = "<leader>tx",
      sync = "<leader>ts",
      panel = "<leader>tp",
    },
  },
  statusline = { enabled = true, format = nil },
  hooks = { on_updated = nil, on_synced = nil, on_reviewed = nil }, -- + User autocmds AgentTrack{Updated,Synced,Reviewed}
})
```

---

## 5. Commands & Keymaps

### `:AgentTrack` Subcommands & Global Keymaps (`lua/plugins/agent-track.lua`)

| Command | Global Key | Action |
| :--- | :--- | :--- |
| `:AgentTrack attach <remote> [session]` | — | Attach local path or SSH URL (`user@host:/repo`) & start watcher |
| `:AgentTrack detach [session]` | — | Stop background watcher for session |
| `:AgentTrack fetch [session]` | `<leader>atf` | Fetch latest `agent`, `base`, and `notes` refs |
| `:AgentTrack review` / `list` | `<leader>atr` | Open `Snacks.picker` subcommit review deck (`vim.ui.select` fallback) |
| `:AgentTrack open [idx\|sha\|id]` | `<leader>ato` | Open subcommit in single reused `[track]` `:CodeDiff` tab |
| `:AgentTrack approve [idx\|sha] [--prefix]` | — | Approve subcommit (or `1..k` watermark with `--prefix`) & push notes |
| `:AgentTrack reject <idx\|sha> <reason>` | — | Reject subcommit with comment & push notes to `R` |
| `:AgentTrack sync [approved\|all\|idx\|sha]` | `<leader>ats` | Fail-fast non-intrusive 3-way merge into working tree |
| `:AgentTrack undo [session]` | `<leader>atu` | Restore exact pre-sync working tree from `undo` stack |
| `:AgentTrack status [session]` | `<leader>ati` | Show counts, sync tip, and watcher mode |
| `:AgentTrack clean [session]` | — | Detach watcher and delete all session refs & notes |

### Review Panel (`Snacks.picker`) & `[track]` `:CodeDiff` Tab Keys

| Context | Key | Action |
| :--- | :--- | :--- |
| **Picker (`<leader>atr`)** | `<CR>` | Open selected subcommit in `[track]` `:CodeDiff <parent> <sha>` tab |
| | `a` / `A` / `x` / `c` | Approve / Prefix-approve `1..idx` / Reject (prompt reason) / Clear to pending |
| | `s` / `S` / `u` / `r` | Sync approved / Sync prefix up to selected / Undo last sync / Fetch & refresh |
| **`[track]` Diff Tab** | `]c` / `[c` | Next / Previous chronological subcommit (reuses single `[track]` tab) |
| | `]f` / `[f` | Next / Previous file in causal `Touch-Order` (`:CodeDiff file <parent> <sha> <path>`) |
| | `<leader>ta` / `<leader>tA` | Approve & advance to next pending / Prefix-approve `1..k` |
| | `<leader>tx` / `<leader>ts` / `<leader>tp` | Reject with comment / Sync / Open review panel |

---

## 6. `:GrantSocket` RPC & CLI (`agent_track.py`)

After running `:GrantSocket` in Neovim (`/tmp/nvim-$USER/nvim-<pid>.sock`), external tools or `.agents/skills/agent-track/scripts/agent_track.py` call:

```bash
nvim --server <sock> --remote-expr 'luaeval("require(\"agent-track\").rpc.dispatch(_A)", "{\"method\":\"list\",\"args\":{\"session\":\"default\"}}")'
```

**Supported `rpc.dispatch` methods**: `ping`/`info`, `init`/`init_session`, `attach`, `detach`, `fetch`, `status`, `list`, `review`, `approve`, `reject`, `apply`/`sync`, `undo`, `clean`, `open`, `panel`, `close`. Returns JSON `{"ok":true,"result":...}` or `{"ok":false,"error":"..."}`.
