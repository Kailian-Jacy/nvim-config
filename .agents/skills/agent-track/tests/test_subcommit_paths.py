"""agent_track.py subcommit: path bookkeeping (renames, deletions) and linked-worktree emission.

Run: python3 .agents/skills/agent-track/tests/test_subcommit_paths.py   (stdlib only, any git >= 2.25)
"""
import json, os, subprocess, tempfile, unittest

AT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "agent_track.py")


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", *args], check=True, capture_output=True, text=True).stdout.strip()


def at(repo, *args):
    return json.loads(subprocess.run(["python3", AT, "-C", repo, "--no-nvim", "--json", *args], check=True, capture_output=True, text=True).stdout)


class SubcommitPaths(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.repo = os.path.join(self.tmp.name, "R")
        os.makedirs(os.path.join(self.repo, "src")); git(self.tmp.name, "init", "-q", self.repo)
        for name, body in {"src/c.rs": "pub fn c() { /* a body long enough for rename detection */ }\n", "src/old.rs": "legacy\n", "src/a.rs": "a\n"}.items():
            with open(os.path.join(self.repo, name), "w") as f: f.write(body)
        git(self.repo, "add", "-A"); git(self.repo, "commit", "-qm", "base")
        at(self.repo, "init-agent", "--session", "s")

    def tearDown(self): self.tmp.cleanup()

    def trailer(self, key):
        return git(self.repo, "log", "-1", f"--format=%(trailers:key={key},valueonly=true,separator=%x2C)", "refs/subcommits/s/agent")

    def test_rename_keeps_real_paths_in_touch_order(self):
        git(self.repo, "mv", "src/c.rs", "src/d.rs"); os.remove(os.path.join(self.repo, "src/old.rs"))
        with open(os.path.join(self.repo, "src/a.rs"), "a") as f: f.write("b\n")
        res = at(self.repo, "subcommit", "--session", "s", "-m", "x", "--files", "src/c.rs,src/d.rs,src/old.rs,src/a.rs", "--order", "src/c.rs,src/a.rs")
        self.assertEqual(self.trailer("Touch-Order"), "src/d.rs, src/a.rs, src/old.rs")  # old rename path maps to its new path
        self.assertEqual((res["files"], res["insertions"], res["deletions"]), (3, 1, 1))
        self.assertNotIn("=>", self.trailer("Touch-Order"))

    def test_linked_worktree_writes_shared_ref_and_reflog(self):
        wt = os.path.join(self.tmp.name, "wt"); git(self.repo, "worktree", "add", "-q", "--detach", wt, "HEAD")
        with open(os.path.join(wt, "src/a.rs"), "w") as f: f.write("from worktree\n")
        res = at(wt, "subcommit", "--session", "s", "--id", "sc-s-01", "-m", "wt slice", "--files", "src/a.rs")
        self.assertEqual(git(self.repo, "rev-parse", "refs/subcommits/s/agent"), res["sha"])
        with open(os.path.join(self.repo, ".git", "logs", "refs", "subcommits", "s", "agent")) as f: self.assertIn("subcommit: wt slice", f.read())
        self.assertEqual(git(self.repo, "status", "--porcelain"), "")  # R's index and working tree untouched
        self.assertEqual(self.trailer("Subcommit-Id"), "sc-s-01")


if __name__ == "__main__":
    unittest.main(verbosity=2)
