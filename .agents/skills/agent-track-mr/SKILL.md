---
name: agent-track-mr
description: "Translate an existing GitLab MR / GitHub PR into a reviewable agent-track subcommit chain (session mr-<N>) without touching the repo's HEAD, index, or working tree, then hand the human the exact `:AgentTrack attach ssh://<host>/<repo> mr-<N>` command to review it slice by slice in Neovim. Use when asked to split, translate, or replay an MR/PR into subcommits for review."
---

# agent-track-mr

Replay an existing MR/PR as a causal chain of atomic shadow subcommits in session `mr-<N>`, so the human reviews it in Neovim exactly like live agent work (see the `agent-track` skill). This is translation, not authoring: the chain must end at exactly the MR head tree.

```bash
AT="$(command -v agent-track || echo "<this-skill-dir>/../agent-track/scripts/agent_track.py")"  # CLI of the sibling agent-track skill
R=/abs/path/to/repo; N=317; S=mr-$N    # R = the agent-side repo the human will attach to
```

**Invariants**
- Never touch R's `HEAD`, branches, index, or working tree, and never push to the MR's remote. State lives only in `refs/subcommits/$S/*`, its notes, and a scratch worktree.
- Always pass `--no-nvim` to `$AT` here: otherwise host commands such as `list`/`clean` may be forwarded to a human's Neovim that has R open.
- Content-preserving: no fixes, renames, or reformatting beyond the MR. Put doubts into `--why` (or the hand-off summary); do not change code.

## 1. Resolve the MR head and base

```bash
git -C "$R" fetch origin "+refs/merge-requests/$N/head:refs/subcommits/$S/mr-head"   # GitLab
# GitHub: "+refs/pull/$N/head:refs/subcommits/$S/mr-head"
```
- Base = the host's MR diff base when available: GitLab `diff_refs.base_sha` from `GET /api/v4/projects/<id>/merge_requests/$N` (or `glab mr view $N -F json`); then `git -C "$R" fetch origin <base_sha>` if missing. Otherwise `git -C "$R" fetch origin <target_branch>` and `BASE=$(git -C "$R" merge-base refs/subcommits/$S/mr-head origin/<target_branch>)`.
- Check `git -C "$R" merge-base --is-ancestor "$BASE" refs/subcommits/$S/mr-head`, and that `mr-head` equals the MR's current head SHA when the API reports it.
- If `refs/subcommits/$S/agent` already exists and differs from base, stop and ask: a review may be in progress, and `init-agent --reset` restarts the chain.

```bash
"$AT" -C "$R" --no-nvim init-agent --session "$S" --base "$BASE"
WT=$(mktemp -d)/wt && git -C "$R" worktree add --detach "$WT" "$BASE"   # scratch worktree; refs are shared with R
```

## 2. Plan the slices before emitting any

Read `git -C "$R" diff --stat "$BASE" refs/subcommits/$S/mr-head`, the per-file diffs, the MR description, and `git -C "$R" log --reverse --oneline "$BASE..refs/subcommits/$S/mr-head"`. Write the plan first: an ordered list of `message / why / files / order`.
- Causal order: contracts, types, schemas, and config surface first, then core mechanism, then call sites and wiring, then tests, then docs, CI, and generated files.
- Keep each slice small (≤5 files, ≤150 changed lines). One file may span several slices, for example types first and logic later.
- Lockfiles, generated, and vendored changes go in their own slice; say so in `--why`.
- Mirror the author's commits 1:1 only when they are already atomic and the range has no merges.
- Prefer slices that build. When a check is cheap, run it in `$WT` after materializing a slice.

## 3. Materialize each slice in `$WT`, then subcommit it

```bash
git -C "$WT" checkout refs/subcommits/$S/mr-head -- src/a.rs src/b.rs   # whole files at MR-head state
git -C "$WT" rm -q -- old/path.rs                                        # deletions; a rename = checkout new + rm old, same slice
# partial file: edit it in $WT to the intermediate state (only this slice's hunks); a later slice checks out the rest
"$AT" -C "$WT" --no-nvim subcommit --session "$S" --id "sc-$S-01" \
  -m "api: define retry policy types" \
  --why "Contract first; the backoff math in sc-$S-02 consumes these types" \
  --files src/a.rs,src/b.rs,old/path.rs --order src/a.rs,src/b.rs,old/path.rs
```
- `--files` scopes the slice to exactly these paths: nothing else in `$WT` leaks in. `--order` is the Touch-Order the reviewer steps with `]f`.
- Use stable ids (`--id sc-$S-NN`, numbered per slice). If you re-slice after feedback, keep the ids: an unchanged patch keeps its approval, and a changed one turns `stale` for re-review.
- `-m` is `scope: imperative summary`, at most 72 chars, in the MR's language. `--why` says what to check and why this slice comes here.

## 4. Verify, then clean the scratch worktree

```bash
git -C "$R" diff --stat refs/subcommits/$S/agent refs/subcommits/$S/mr-head   # must print nothing
"$AT" -C "$R" --no-nvim list --session "$S"                                   # slices, order, Touch-Order
git -C "$R" worktree remove --force "$WT"                                     # refs and notes stay
```
If the diff is not empty, add slices for the leftovers; never finish with a tree mismatch. Confirm that `git -C "$R" status --short` and `HEAD` match what they were before you started.

## 5. Hand off: give the human the complete command

The human runs this in Neovim inside L, their checkout of the same repository. Run `git fetch origin` there first so the MR base exists locally.

```bash
P=$(realpath "$R"); H=$(realpath "$HOME"); case "$P" in "$H"/*) P="$HOME${P#"$H"}";; esac
echo ":AgentTrack attach ssh://<ssh-host>$P $S"     # e.g. :AgentTrack attach ssh://hg/home/xuzian/dsh/research-platform mr-317
```
- `<ssh-host>` is the alias the human uses for the agent host (`hg` or `df`, see `dev-machines`). If L and R are on the same machine, use the plain path: `:AgentTrack attach $P $S`.
- Reply with the command, the MR link and SHAs (`base..mr-head`), and a slice table (index, id, subject, files, +/-), plus review keys: `<leader>atr` panel; in the `[track]` tab `<leader>tj`/`<leader>tk` move between subcommits, `]f`/`[f` step Touch-Order files, `<leader>ta` approves, `<leader>tc` approves with a comment, `<leader>tx` rejects.

## 6. Review loop and cleanup

- `"$AT" -C "$R" --no-nvim inbox --session "$S" --json` shows notes. Rejected means re-slice: recreate the worktree at the parent of the first rejected slice and re-emit from there with `subcommit --parent <sha>` and the same ids. Approved comments are non-blocking notes for the MR author.
- If the MR head moves, re-fetch `mr-head` and re-slice with the same ids.
- When the review is over and the human agrees, run `"$AT" -C "$R" --no-nvim clean --session "$S"`. It deletes `refs/subcommits/$S/*`, including `mr-head`, and the session notes.
