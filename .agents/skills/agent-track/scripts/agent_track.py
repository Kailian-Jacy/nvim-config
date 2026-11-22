#!/usr/bin/env python3
"""Harness-agnostic Git shadow-ref subcommit CLI & Neovim RPC client for agent-track."""
from __future__ import annotations
import argparse, getpass, glob, json, os, shutil, subprocess, sys, tempfile, time

class TrackError(Exception): pass
def _csv(vals) -> list[str]: return [p.strip() for v in (vals or []) for p in v.split(",") if p.strip()]

class Ctx:
    def __init__(self, cwd: str, session: str, ref_prefix: str, notes_prefix: str):
        p = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        if p.returncode != 0: raise TrackError(f"not a git repository: {cwd}")
        self.repo, self.session, self.ref_prefix = os.path.realpath(p.stdout.strip()), session, ref_prefix.rstrip("/")
        np = notes_prefix.strip("/")
        self.notes_ref = f"{np}/{session}" if np.startswith("refs/notes") else f"refs/notes/{np}/{session}"
        self.id_args = [x for k, fb in (("user.name", "agent-track"), ("user.email", "agent-track@local"))
                        if not subprocess.run(["git", "-C", self.repo, "config", "--get", k], capture_output=True, text=True).stdout.strip() for x in ("-c", f"{k}={fb}")]
    def ref(self, name: str) -> str: return f"{self.ref_prefix}/{self.session}/{name}"
    def git(self, *args: str, inp: str | None = None, env_extra: dict | None = None, check: bool = True):
        cmd = ["git", "-C", self.repo, "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false", "-c", "core.logAllRefUpdates=always", *self.id_args, *args]
        r = subprocess.run(cmd, input=inp, env={**os.environ, **env_extra} if env_extra else None, capture_output=True, text=True)
        if check and r.returncode != 0: raise TrackError(f"git {' '.join(args[:3])} failed: {r.stderr.strip() or r.returncode}")
        return r
    def rev(self, spec: str) -> str | None:
        return r.stdout.strip() if (r := self.git("rev-parse", "--verify", "--quiet", spec, check=False)).returncode == 0 and r.stdout.strip() else None
    def is_anc(self, a: str | None, b: str | None) -> bool:
        return bool(a and b and self.git("merge-base", "--is-ancestor", a, b, check=False).returncode == 0)
    def relpath(self, p: str) -> str:
        if os.path.isabs(p):
            return p.strip("/") if (rel := os.path.relpath(os.path.realpath(p), self.repo).replace(os.sep, "/")).startswith("..") else rel
        if (cwd := os.path.realpath(os.getcwd())) != self.repo and cwd.startswith(self.repo + os.sep) and os.path.lexists(os.path.join(cwd, p)):
            return os.path.relpath(os.path.realpath(os.path.join(cwd, p)), self.repo).replace(os.sep, "/")
        return "" if (n := os.path.normpath(p).replace(os.sep, "/")) == "." else n
    def state(self) -> dict:
        try: return json.loads(self.git("cat-file", "-p", s).stdout) if (s := self.rev(self.ref("state"))) else {"remote": None, "session": self.session, "applied_ids": []}
        except json.JSONDecodeError: return {"remote": None, "session": self.session, "applied_ids": []}
    def save_state(self, st: dict):
        self.git("update-ref", self.ref("state"), self.git("hash-object", "-w", "--stdin", inp=json.dumps(st)).stdout.strip())

def _patch_ids(ctx: Ctx, spec: str) -> dict[str, str]:
    raw = ctx.git("log", "-p", spec, check=False).stdout
    return {p[1]: p[0] for l in (ctx.git("patch-id", "--stable", inp=raw, check=False).stdout.splitlines() if raw else []) if len(p := l.split()) >= 2}

def parse_note(raw: str) -> dict:
    """Append-only JSONL note: {"t":"review",...} (latest wins) and {"t":"comment","path","side","line","end_line","body"} events.
    A legacy single-object note {"status","comment",...} reads as one review (+ one file-less comment)."""
    ev = []
    for ln in (raw or "").splitlines():
        try: o = json.loads(ln.strip())
        except json.JSONDecodeError: continue
        if not isinstance(o, dict): continue
        if o.get("t") in ("review", "comment"): ev.append(o)
        elif o.get("status"):
            at = int(o.get("updated_at") or 0)
            ev.append({"t": "review", "status": o["status"], "at": at, "subcommit_id": o.get("subcommit_id"), "patch_id": o.get("patch_id")})
            if o.get("comment"): ev.append({"t": "comment", "body": o["comment"], "at": at})
    ev = [e for _, e in sorted(enumerate(ev), key=lambda p: (int(p[1].get("at") or 0), p[0]))]
    review = next((e for e in reversed(ev) if e["t"] == "review"), None)
    return {"review": review, "comments": [e for e in ev if e["t"] == "comment"], "subcommit_id": (review or {}).get("subcommit_id")}

def comment_loc(c: dict) -> str:
    if not c.get("path"): return ""
    ln = c.get("line"); rng = f"{ln}-{c['end_line']}" if c.get("end_line") else f"{ln}"
    return f"{c['path']}:{rng}" + (" (old)" if c.get("side") == "old" else "")

def _orphan_notes(ctx: Ctx) -> dict[str, dict]:
    blobs = [l.split()[0] for l in ctx.git("notes", f"--ref={ctx.notes_ref}", "list", check=False).stdout.splitlines() if l.strip()] if ctx.rev(ctx.notes_ref) else []
    by_id: dict[str, dict] = {}
    for ch in (ctx.git("cat-file", "--batch=\x1e", inp="\n".join(blobs) + "\n").stdout.split("\x1e\n")[1:] if blobs else []):
        r = parse_note(ch).get("review")
        if r and (sid := r.get("subcommit_id")) and int(r.get("at") or 0) >= int(by_id.get(sid, {}).get("at", -1)): by_id[sid] = r
    return by_id

def collect_items(ctx: Ctx) -> dict:
    base, agent, synced, app_ref = (ctx.rev(ctx.ref(k)) for k in ("base", "agent", "synced", "approved"))
    st, items = ctx.state(), []
    applied = set(st.get("applied_ids") or [])
    if base and agent and base != agent:
        fmt = "%H%x00%P%x00%at%x00%s%x00%(trailers:key=Subcommit-Id,valueonly=true,separator=,)%x00%(trailers:key=Touch-Order,valueonly=true,separator=,)%x00%N%x1e"
        recs = [r.lstrip("\r\n") for r in ctx.git("log", "--reverse", f"--notes={ctx.notes_ref}", f"--format={fmt}", f"{base}..{agent}").stdout.split("\x1e") if r.strip()]
        orphans = _orphan_notes(ctx) if any(len(f := r.split("\x00")) >= 7 and not f[6].strip() for r in recs) else {}
        pids = _patch_ids(ctx, f"{base}..{agent}") if orphans else {}
        for idx, rec in enumerate(recs, 1):
            if len(f := rec.split("\x00")) < 7: continue
            sha, parents, at, subj, sid, tord, nraw = f[:7]
            parent, sid = (parents.split()[0] if parents.strip() else base), sid.strip().split(",")[0].strip()
            touch = [p.strip() for p in tord.replace("\n", ",").split(",") if p.strip()]
            status, via = "pending", "none"
            pn = parse_note(nraw) if nraw.strip() else {"review": None, "comments": []}
            comments, note = pn["comments"], pn["review"]
            if note and note.get("status"): status, via = note["status"], "note"
            elif sid and sid in orphans:
                on = orphans[sid]
                status = on["status"] if (on.get("patch_id") and pids.get(sha) == on.get("patch_id")) or on.get("status") != "approved" else "stale"
                via = "rewrite"
            elif app_ref and ctx.is_anc(sha, app_ref): status, via = "approved", "prefix"
            comment = comments[-1].get("body", "") if comments else ""
            items.append({"index": idx, "sha": sha, "short_sha": sha[:7], "parent": parent, "author_time": int(at or 0), "subject": subj,
                          "subcommit_id": sid, "touch_order": touch, "status": status, "review_status": status,
                          "review_via": via, "comment": comment, "comments": comments, "synced": bool((synced and ctx.is_anc(sha, synced)) or (sid and sid in applied))})
    counts = {**{k: sum(1 for i in items if i["review_status"] == k) for k in ("approved", "rejected", "stale", "pending")}, "total": len(items)}
    return {"ok": True, "repo": ctx.repo, "session": ctx.session, "remote": st.get("remote"), "base": base, "agent": agent, "synced": synced,
            "approved_prefix": app_ref, "counts": counts, "items": items, **{k: [i for i in items if i["review_status"] == k] for k in ("rejected", "stale")}}

def _materialize(ctx: Ctx, old_tree: str, new_tree: str):
    dt, co = ctx.git("diff-tree", "-r", "--name-status", "-z", old_tree, new_tree).stdout.split("\x00"), []
    for st, path in zip(dt[0::2], dt[1::2]):
        if path and st.startswith("D") and os.path.lexists(full := os.path.join(ctx.repo, path)): os.unlink(full)
        elif path and not st.startswith("D"): co.append(path)
    if co:
        with tempfile.TemporaryDirectory() as td:
            env = {"GIT_INDEX_FILE": os.path.join(td, "idx")}
            ctx.git("read-tree", new_tree, env_extra=env); ctx.git("checkout-index", "-f", "--", *co, env_extra=env)

def _snap_worktree(ctx: Ctx, base_tree: str, tracked_only: bool = False) -> str:
    with tempfile.TemporaryDirectory() as td:
        idx, ridx = os.path.join(td, "idx"), os.path.join(ctx.git("rev-parse", "--path-format=absolute", "--git-dir").stdout.strip(), "index")
        shutil.copyfile(ridx, idx) if os.path.exists(ridx) else ctx.git("read-tree", base_tree, env_extra={"GIT_INDEX_FILE": idx})
        ctx.git("add", "-u" if tracked_only else "-A", "--", ".", env_extra={"GIT_INDEX_FILE": idx})
        return ctx.git("write-tree", env_extra={"GIT_INDEX_FILE": idx}).stdout.strip()

def cmd_init_agent(ctx: Ctx, args) -> dict:
    if not (b := ctx.rev(f"{args.base or 'HEAD'}^{{commit}}")): raise TrackError(f"cannot resolve base: {args.base or 'HEAD'}")
    if args.reset or not ctx.rev(ctx.ref("base")) or ctx.rev(ctx.ref("agent")) in (None, ctx.rev(ctx.ref("base"))):
        ctx.git("update-ref", "-m", "init-agent: base", ctx.ref("base"), b); ctx.git("update-ref", "--create-reflog", "-m", "init-agent", ctx.ref("agent"), b)
    elif args.base: ctx.git("update-ref", "-m", "init-agent: base", ctx.ref("base"), b)
    return {"ok": True, "session": ctx.session, "repo": ctx.repo, "base": ctx.rev(ctx.ref("base")), "agent": ctx.rev(ctx.ref("agent"))}

def cmd_subcommit(ctx: Ctx, args) -> dict:
    if not ctx.rev(ctx.ref("base")): cmd_init_agent(ctx, argparse.Namespace(base="HEAD", reset=False))
    base_sha = ctx.rev(ctx.ref("base"))
    cur_agent, reused_id = ctx.rev(ctx.ref("agent")) or base_sha, None
    if args.parent:
        if not (parent := ctx.rev(f"{args.parent}^{{commit}}")): raise TrackError(f"unknown --parent: {args.parent}")
    elif args.amend:
        if cur_agent == base_sha: raise TrackError("nothing to amend: no subcommits in session yet")
        parent = ctx.rev(f"{cur_agent}^") or base_sha
        reused_id = ctx.git("log", "-1", "--format=%(trailers:key=Subcommit-Id,valueonly=true,separator=,)", cur_agent).stdout.strip().split(",")[0].strip()
    else: parent = cur_agent
    files = [p for p in (ctx.relpath(x) for x in _csv(args.files)) if p]
    with tempfile.TemporaryDirectory() as td:
        env = {"GIT_INDEX_FILE": os.path.join(td, "idx")}
        ctx.git("read-tree", parent, env_extra=env); ctx.git("add", "-A", "--", *(files or ["."]), env_extra=env)
        tree = ctx.git("write-tree", env_extra=env).stdout.strip()
    if tree == ctx.rev(f"{parent}^{{tree}}") and not args.allow_empty: raise TrackError("no changes to subcommit relative to parent subcommit")
    changed, renamed, ins, dels = [], {}, 0, 0
    toks, i = ctx.git("diff-tree", "-r", "--numstat", "-M", "-z", parent, tree).stdout.split("\x00"), 0
    while i < len(toks) and len(p := toks[i].split("\t", 2)) == 3:  # -z: "a\td\tpath\0"; renames "a\td\t\0old\0new\0" (keep new path)
        if p[2]: path, i = p[2], i + 1
        else: path, i = (toks[i + 2] if i + 2 < len(toks) else ""), i + 3; renamed[toks[i - 2]] = path
        ins, dels = ins + (int(p[0]) if p[0].isdigit() else 0), dels + (int(p[1]) if p[1].isdigit() else 0)
        if path: changed.append(path)
    coaching = f"subcommit touches {len(changed)} files (+{ins}/-{dels}), exceeding atomic guideline (<=5 files, <=150 lines); split with --files." if ins + dels > 150 or len(changed) > 5 else None
    if coaching and args.strict: raise TrackError(coaching)
    if coaching: print(f"[agent-track coaching] {coaching}", file=sys.stderr)
    ord_req = [renamed.get(p, p) for p in (ctx.relpath(x) for x in _csv(args.order)) if p]
    touch = list(dict.fromkeys(([p for p in ord_req if p in changed] or ord_req) + changed))
    sid = args.id or reused_id or f"sc-{time.strftime('%Y%m%d%H%M%S')}-{os.urandom(2).hex()}"
    subj, body = args.message.strip(), (args.why or "").strip()
    msg = subj + (f"\n\n{body}" if body else "") + f"\n\nSubcommit-Id: {sid}\nTouch-Order: {', '.join(touch)}\n"
    if args.branch_mode == "branch": ctx.git("add", "-A", "--", *(files or ["."])); ctx.git("commit", "-m", msg); new_sha = ctx.rev("HEAD")
    else: new_sha = ctx.git("commit-tree", tree, "-p", parent, inp=msg).stdout.strip()
    ctx.git("update-ref", "--create-reflog", "-m", f"subcommit: {subj}", ctx.ref("agent"), new_sha)
    notified = False
    if args.notify_nvim and (sock := _find_socket(args, None, quiet=True)):
        try: _rpc(sock, "fetch", {"session": ctx.session}); notified = True
        except TrackError: pass
    ib = collect_items(ctx)
    alerts = [f"  - [REJECTED] {r['short_sha']} ({r['subcommit_id']}): {r['comment'] or r['subject']}" for r in ib["rejected"]]
    alerts += [f"  - [COMMENT] {i['short_sha']} ({i['subcommit_id']}) {comment_loc(c) or '(subcommit)'}: {c.get('body','')}" for i in ib["items"] for c in i.get("comments", []) if c.get("at", 0) and i["review_status"] != "approved"]
    if alerts: print("[agent-track inbox] Action required:\n" + "\n".join(alerts), file=sys.stderr)
    return {"ok": True, "session": ctx.session, "sha": new_sha, "short_sha": new_sha[:7], "parent": parent, "subcommit_id": sid, "touch_order": touch,
            "files": len(changed), "insertions": ins, "deletions": dels, "branch_mode": args.branch_mode, "notified_nvim": notified,
            "coaching_warning": coaching, "inbox": {k: ib[k] for k in ("counts", "rejected")}}

def _rpc(sock: str, method: str, rpc_args: dict) -> dict:
    q = "'" + json.dumps({"method": method, "args": rpc_args}).replace("'", "''") + "'"
    p = subprocess.run(["nvim", "--server", sock, "--remote-expr", f'luaeval("require(\\"agent-track\\").rpc.dispatch(_A)", {q})'], capture_output=True, text=True, timeout=15)
    if p.returncode != 0 or not p.stdout.strip(): raise TrackError(f"nvim RPC failed on {sock}: {p.stderr.strip() or p.stdout.strip() or p.returncode}")
    res = json.loads(r) if isinstance(r := json.loads(p.stdout.strip()), str) else r
    if isinstance(res, dict) and res.get("ok") is False: raise TrackError(str(res.get("error") or "RPC error"))
    return res["result"] if isinstance(res, dict) and isinstance(res.get("result"), dict) else {"ok": True, "result": res}

def _find_socket(args, repo: str | None, quiet: bool = False) -> str | None:
    if getattr(args, "no_nvim", False): return None
    for s in (getattr(args, "socket", None), os.environ.get("AGENT_TRACK_SOCKET"), os.environ.get("WALK_COMMIT_SOCKET")):
        if s: return s
    sdir, matches = os.environ.get("NVIM_AGENT_SOCKET_DIR") or f"/tmp/nvim-{os.environ.get('USER') or getpass.getuser()}", []
    for path in sorted(glob.glob(os.path.join(sdir, "nvim-*.sock"))):
        try:
            p = subprocess.run(["nvim", "--server", path, "--remote-expr", "luaeval('vim.fn.getcwd()')"], capture_output=True, text=True, timeout=2)
            if p.returncode != 0 or not p.stdout.strip(): continue
            gr = subprocess.run(["git", "-C", p.stdout.strip(), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
            if not repo or os.path.realpath(gr.stdout.strip() if gr.returncode == 0 and gr.stdout.strip() else p.stdout.strip()) == os.path.realpath(repo): matches.append(path)
        except (OSError, subprocess.TimeoutExpired): continue
    if len(matches) > 1 and not quiet: raise TrackError(f"multiple Neovim sockets matched ({matches}); pass --socket or --repo")
    return matches[0] if len(matches) == 1 else None

def _pick(items: list[dict], tgt: str | None, pending: bool = True) -> dict:
    if not items: raise TrackError("no subcommits in session")
    if not tgt: return next((i for i in items if i["review_status"] in ("pending", "stale")), items[-1]) if pending else items[-1]
    if tgt.isdigit() and 1 <= int(tgt) <= len(items): return items[int(tgt) - 1]
    if hit := next((i for i in items if i["sha"].startswith(tgt) or i["subcommit_id"] == tgt), None): return hit
    raise TrackError(f"subcommit not found: {tgt}")

def _write_note(ctx: Ctx, it: dict, status: str, comment: str, remote: str | None):
    now = int(time.time())
    ev = [{"t": "review", "status": status, "at": now, "subcommit_id": it["subcommit_id"], "patch_id": _patch_ids(ctx, f"{it['parent']}..{it['sha']}").get(it["sha"], "")}]
    if comment: ev.append({"t": "comment", "body": comment, "at": now, "subcommit_id": it["subcommit_id"]})
    for e in ev: ctx.git("notes", f"--ref={ctx.notes_ref}", "append", "--no-separator", "-m", json.dumps(e, ensure_ascii=False), it["sha"])
    if remote: ctx.git("push", remote, f"+{ctx.notes_ref}:{ctx.notes_ref}", check=False)

def _host_git(ctx: Ctx, cmd: str, args) -> dict:
    st = ctx.state(); remote = st.get("remote")
    if cmd == "attach": st["remote"] = remote = args.remote; ctx.save_state(st); cmd = "fetch"
    if cmd == "fetch":
        if not remote: raise TrackError("no remote attached; run `attach <agent_repo_or_ssh_url>`")
        for r in (ctx.ref("base"), ctx.ref("agent"), ctx.notes_ref): ctx.git("fetch", "--no-write-fetch-head", remote, f"+{r}:{r}", check=False)
        if not ctx.rev(ctx.ref("synced")) and (b := ctx.rev(ctx.ref("base"))): ctx.git("update-ref", ctx.ref("synced"), b)
        return collect_items(ctx)
    if cmd == "list": return collect_items(ctx)
    if cmd == "open": return {"ok": True, "item": (it := _pick(collect_items(ctx)["items"], args.target)), "diff": ctx.git("show", "--stat", "-p", it["sha"]).stdout}
    if cmd in ("approve", "reject"):
        it, status, pfx = _pick(collect_items(ctx)["items"], args.target, cmd == "approve" and not getattr(args, "prefix", False)), ("approved" if cmd == "approve" else "rejected"), bool(getattr(args, "prefix", False))
        if status == "approved" and pfx:
            ctx.git("update-ref", ctx.ref("approved"), it["sha"])
            if remote: ctx.git("push", remote, f"+{ctx.ref('approved')}:{ctx.ref('approved')}", check=False)
        else: _write_note(ctx, it, status, getattr(args, "reason", "") or "", remote)
        return {"ok": True, "sha": it["sha"], "status": status, "prefix": pfx}
    if cmd == "sync":
        ib, tgt = collect_items(ctx), args.target or "approved"
        ps = ib["synced"] or ib["base"]
        if tgt == "approved":
            if not (app := [i for i in ib["items"] if i["review_status"] == "approved" and not i["synced"]]): return {"ok": True, "synced": ps}
            acc = f"{ps}^{{tree}}"
            for i in app:
                m = ctx.git("merge-tree", "--write-tree", f"--merge-base={i['parent']}", acc, i["sha"], check=False)
                if m.returncode != 0: raise TrackError("cherry-sync conflict across subcommits")
                acc = m.stdout.splitlines()[0].strip(); st.setdefault("applied_ids", []).append(i["subcommit_id"])
            ns = ctx.git("commit-tree", acc, "-p", ps, inp=f"sync\n\nApplied-Subcommits: {','.join(i['sha'] for i in app)}\n").stdout.strip()
        else:
            if not ib["items"]: return {"ok": True, "synced": ps}
            ns = ib["items"][-1]["sha"] if tgt == "all" else _pick(ib["items"], tgt, False)["sha"]
        wt = _snap_worktree(ctx, f"{ps}^{{tree}}", True)
        mt = ctx.git("merge-tree", "--write-tree", "--name-only", "-z", f"--merge-base={ps}", ctx.git("commit-tree", wt, "-p", ps, inp="w\n").stdout.strip(), ns, check=False)
        parts = mt.stdout.split("\x00\x00", 1)[0].split("\x00")
        if mt.returncode != 0: raise TrackError(f"merge conflict with local edits on {', '.join(p for p in parts[1:] if p)} (revert local changes or reject subcommit)")
        pu = ctx.rev(ctx.ref("undo"))
        ctx.git("update-ref", ctx.ref("undo"), ctx.git("commit-tree", wt, *(["-p", pu] if pu else []), inp=f"undo\n\nRestores-Synced: {ps}\nRestores-Applied: {','.join(ctx.state().get('applied_ids') or [])}\n").stdout.strip())
        _materialize(ctx, wt, parts[0].strip()); ctx.git("update-ref", ctx.ref("synced"), ns); ctx.save_state(st)
        return {"ok": True, "synced": ns}
    if cmd == "undo":
        if not (u := ctx.rev(ctx.ref("undo"))): raise TrackError("nothing to undo")
        m = ctx.git("log", "-1", "--format=%P%x00%(trailers:key=Restores-Synced,valueonly=true,separator=,)%x00%(trailers:key=Restores-Applied,valueonly=true,separator=,)", u).stdout.split("\x00")
        _materialize(ctx, _snap_worktree(ctx, f"{ctx.rev(ctx.ref('synced')) or ctx.rev(ctx.ref('base')) or 'HEAD'}^{{tree}}", True), f"{u}^{{tree}}")
        if len(m) > 1 and m[1].strip(): ctx.git("update-ref", ctx.ref("synced"), m[1].strip())
        if len(m) > 2: st["applied_ids"] = [x.strip() for x in m[2].split(",") if x.strip()]; ctx.save_state(st)
        ctx.git("update-ref", *([ctx.ref("undo"), m[0].split()[0]] if m[0].strip() else ["-d", ctx.ref("undo")]))
        return {"ok": True, "restored": u}
    for r in [*ctx.git("for-each-ref", "--format=%(refname)", f"{ctx.ref_prefix}/{ctx.session}/").stdout.splitlines(), ctx.notes_ref]:
        if r.strip() and ctx.rev(r.strip()): ctx.git("update-ref", "-d", r.strip())
    return {"ok": True, "cleaned_session": ctx.session}

def main() -> int:
    def cp(r: bool):
        d, p = (None if r else argparse.SUPPRESS), argparse.ArgumentParser(add_help=r, description=__doc__ if r else None)
        for flags, dv in ((("--repo", "-C"), "."), (("--socket",), None), (("--session", "-s"), os.environ.get("AGENT_TRACK_SESSION", "default")),
                          (("--ref-prefix",), os.environ.get("AGENT_TRACK_REF_PREFIX", "refs/subcommits")), (("--notes-prefix",), os.environ.get("AGENT_TRACK_NOTES_PREFIX", "subcommits"))):
            p.add_argument(*flags, default=dv if r else d)
        for f in ("--no-nvim", "--json"): p.add_argument(f, action="store_true", default=False if r else d)
        return p
    root, common = cp(True), [cp(False)]
    sub = root.add_subparsers(dest="cmd", required=True)
    sp = sub.add_parser("init-agent", parents=common); sp.add_argument("--base"); sp.add_argument("--reset", action="store_true")
    sp = sub.add_parser("subcommit", parents=common); sp.add_argument("-m", "--message", required=True); sp.add_argument("--why", "--body", default="")
    for f in ("--order", "--files"): sp.add_argument(f, action="append")
    for f in ("--id", "--parent"): sp.add_argument(f)
    for f in ("--amend", "--allow-empty", "--strict", "--notify-nvim"): sp.add_argument(f, action="store_true")
    sp.add_argument("--branch-mode", choices=("shadow", "branch"), default="shadow")
    for c in ("inbox", "status", "fetch", "list", "undo", "clean"): sub.add_parser(c, parents=common)
    sp = sub.add_parser("attach", parents=common); sp.add_argument("remote")
    sp = sub.add_parser("open", parents=common); sp.add_argument("target", nargs="?")
    sp = sub.add_parser("approve", parents=common); sp.add_argument("target", nargs="?"); sp.add_argument("--prefix", action="store_true")
    sp = sub.add_parser("reject", parents=common); sp.add_argument("target"); sp.add_argument("-m", "--reason", required=True)
    sp = sub.add_parser("sync", parents=common); sp.add_argument("target", nargs="?", default="approved")
    args = root.parse_args()
    try:
        ctx = Ctx(args.repo, args.session, args.ref_prefix, args.notes_prefix)
        if args.cmd == "init-agent": res = cmd_init_agent(ctx, args)
        elif args.cmd == "subcommit": res = cmd_subcommit(ctx, args)
        elif args.cmd in ("inbox", "status"):
            res = _rpc(s, "status", {"session": ctx.session}) if args.cmd == "status" and (s := _find_socket(args, ctx.repo, True)) else collect_items(ctx)
        elif sock := _find_socket(args, ctx.repo):
            s, t, r = ctx.session, getattr(args, "target", None), getattr(args, "reason", "")
            m, rargs = {"attach": ("attach", {"remote": getattr(args, "remote", None), "session": s}), "fetch": ("fetch", {"session": s}), "list": ("list", {"session": s}),
                        "open": ("open", {"target": t, "session": s}), "approve": ("review", {"target": t, "status": "approved", "prefix": bool(getattr(args, "prefix", False)), "session": s}),
                        "reject": ("review", {"target": t, "status": "rejected", "comment": r, "session": s}), "sync": ("apply", {"target": t or "approved", "session": s}),
                        "undo": ("undo", {"session": s}), "clean": ("clean", {"session": s})}[args.cmd]
            res = _rpc(sock, m, rargs)
        else: res = _host_git(ctx, args.cmd, args)
    except (TrackError, subprocess.TimeoutExpired) as e:
        print(json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False) if args.json else f"agent-track error: {e}", file=sys.stdout if args.json else sys.stderr); return 1
    if args.json: print(json.dumps(res, ensure_ascii=False, indent=2))
    elif isinstance(res, dict) and "items" in res:
        c = res.get("counts", {})
        print(f"session={res['session']} total={c.get('total',0)} approved={c.get('approved',0)} rejected={c.get('rejected',0)} stale={c.get('stale',0)} pending={c.get('pending',0)}")
        for i in res["items"]:
            print(f"  {'●' if i['synced'] else '○'} [{i['index']}] {i['short_sha']} ({i['review_status']}) {i['subject']}  Touch: {', '.join(i['touch_order'])}")
            for c in i.get("comments", []): print(f"        comment {comment_loc(c) or '(subcommit)'}: {c.get('body', '')}")
    elif isinstance(res, dict) and "diff" in res: print(res["diff"])
    else: print(json.dumps(res, ensure_ascii=False))
    return 0
if __name__ == "__main__": sys.exit(main())
