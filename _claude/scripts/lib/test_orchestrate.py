#!/usr/bin/env python3
"""orchestrate の単体テスト。

実行: python3 ~/.claude/scripts/lib/test_orchestrate.py -v
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import orchestrate  # noqa: E402


def git(cwd, *args):
    return subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=True, capture_output=True, text=True,
    ).stdout


def make_repo(parent, name="app"):
    root = Path(parent) / name
    root.mkdir()
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "t@example.com")
    git(root, "config", "user.name", "t")
    (root / "README.md").write_text("hello\n")
    git(root, "add", ".")
    git(root, "commit", "-q", "-m", "init")
    return root


class FakeHerdr:
    def __init__(self, launch_rc=0, agents=None):
        self.launch_rc = launch_rc
        self.agents = agents or {}
        self.launched = []
        self.closed = []

    def launch(self, directory, prompt):
        self.launched.append((directory, prompt))
        name = os.path.basename(directory)
        self.agents.setdefault(name, {"agent_status": "working", "workspace_id": "w9"})
        return self.launch_rc, name

    def get(self, name):
        return self.agents.get(name)

    def close_workspace(self, workspace_id):
        self.closed.append(workspace_id)
        return True


def fill(path, purpose="README に 1 行追加する"):
    text = Path(path).read_text()
    Path(path).write_text(text.replace("## 目的\n", f"## 目的\n\n{purpose}\n", 1))


class SlugTest(unittest.TestCase):
    def test_accepts_lowercase_digits_and_hyphen(self):
        self.assertEqual(orchestrate.validate_slug("order-csv-2"), "order-csv-2")

    def test_rejects_invalid(self):
        for bad in ["", "Order", "a b", "../x", "-x", "a_b", "x" * 41]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                orchestrate.validate_slug(bad)


class SectionTest(unittest.TestCase):
    def test_template_is_unfilled(self):
        text = orchestrate.render_template("demo")
        self.assertFalse(orchestrate.is_filled(text))
        self.assertFalse(orchestrate.has_result(text))

    def test_filled_purpose(self):
        text = orchestrate.render_template("demo").replace("## 目的\n", "## 目的\n\nやること\n", 1)
        self.assertTrue(orchestrate.is_filled(text))

    def test_extract_section_ignores_comments_and_stops_at_next_heading(self):
        text = "# t\n\n## 結果\n\n<!-- memo -->\n変更した\n\n## 次\n\nx\n"
        self.assertEqual(orchestrate.extract_section(text, "結果"), "変更した")

    def test_has_result(self):
        text = orchestrate.render_template("demo") + "\n- テスト通過\n"
        self.assertTrue(orchestrate.has_result(text))


class PathTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = make_repo(self.tmp.name)
        self.base = Path(self.tmp.name) / "briefs"

    def tearDown(self):
        self.tmp.cleanup()

    def test_resolve_root_from_main_and_linked_worktree(self):
        wt = Path(self.tmp.name) / "wt"
        git(self.repo, "worktree", "add", "-q", "-b", "x", str(wt))
        self.assertEqual(orchestrate.resolve_root(str(self.repo)), str(self.repo))
        self.assertEqual(orchestrate.resolve_root(str(wt / ".")), str(self.repo))

    def test_resolve_root_outside_git(self):
        with self.assertRaises(ValueError):
            orchestrate.resolve_root(self.tmp.name)

    def test_brief_path_creates_template_once(self):
        path = orchestrate.ensure_brief(str(self.repo), "demo", base=self.base)
        self.assertEqual(path, str(self.base / "app" / "demo.md"))
        self.assertIn("# demo", Path(path).read_text())
        Path(path).write_text("edited")
        orchestrate.ensure_brief(str(self.repo), "demo", base=self.base)
        self.assertEqual(Path(path).read_text(), "edited")

    def test_worktree_path_is_sibling(self):
        self.assertEqual(
            orchestrate.worktree_path(str(self.repo), "demo"),
            str(Path(self.tmp.name) / "app-demo"),
        )


class DispatchTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = make_repo(self.tmp.name)
        self.base = Path(self.tmp.name) / "briefs"
        self.herdr = FakeHerdr()
        self.brief = orchestrate.ensure_brief(str(self.repo), "demo", base=self.base)

    def tearDown(self):
        self.tmp.cleanup()

    def dispatch(self):
        return orchestrate.dispatch(str(self.repo), "demo", self.herdr, base=self.base)

    def test_refuses_unfilled_brief(self):
        with self.assertRaises(ValueError):
            self.dispatch()
        self.assertEqual(self.herdr.launched, [])

    def test_creates_worktree_launches_child_and_records_meta(self):
        fill(self.brief)
        rc, lines = self.dispatch()
        wt = Path(self.tmp.name) / "app-demo"
        self.assertEqual(rc, 0)
        self.assertTrue((wt / "README.md").exists())
        self.assertEqual(git(wt, "branch", "--show-current").strip(), "task/demo")
        directory, prompt = self.herdr.launched[0]
        self.assertEqual(directory, str(wt))
        self.assertIn(self.brief, prompt)
        self.assertIn("## 結果", prompt)
        meta = json.loads((self.base / "app" / "demo.json").read_text())
        self.assertEqual(meta["agent"], "app-demo")
        self.assertEqual(meta["workspace_id"], "w9")
        self.assertEqual(meta["branch"], "task/demo")
        self.assertEqual(meta["base"], git(self.repo, "rev-parse", "HEAD").strip())
        self.assertTrue(any("app-demo" in line for line in lines))

    def test_refuses_second_dispatch(self):
        fill(self.brief)
        self.dispatch()
        with self.assertRaises(ValueError):
            self.dispatch()

    def test_passes_through_blocked_exit_code(self):
        fill(self.brief)
        self.herdr.launch_rc = 3
        rc, _ = self.dispatch()
        self.assertEqual(rc, 3)
        self.assertTrue((self.base / "app" / "demo.json").exists())

    def test_copies_untracked_claude_files_only(self):
        (self.repo / ".claude" / "skills" / "s").mkdir(parents=True)
        (self.repo / ".claude" / "skills" / "s" / "SKILL.md").write_text("local skill")
        (self.repo / ".claude" / "settings.local.json").write_text("{}")
        (self.repo / "CLAUDE.local.md").write_text("local")
        (self.repo / ".claude" / "agents").mkdir()
        (self.repo / ".claude" / "agents" / "tracked.md").write_text("v1")
        (self.repo / "other.txt").write_text("not copied")
        git(self.repo, "add", "-f", ".claude/agents/tracked.md")
        git(self.repo, "commit", "-q", "-m", "agent")
        (self.repo / ".claude" / "agents" / "tracked.md").write_text("v2 uncommitted")
        fill(self.brief)
        _, lines = self.dispatch()
        wt = Path(self.tmp.name) / "app-demo"
        self.assertEqual((wt / ".claude" / "skills" / "s" / "SKILL.md").read_text(), "local skill")
        self.assertTrue((wt / ".claude" / "settings.local.json").exists())
        self.assertTrue((wt / "CLAUDE.local.md").exists())
        self.assertEqual((wt / ".claude" / "agents" / "tracked.md").read_text(), "v1")
        self.assertFalse((wt / "other.txt").exists())
        self.assertTrue(any("CLAUDE.local.md" in line for line in lines))


class StatusCollectCleanupTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = make_repo(self.tmp.name)
        self.base = Path(self.tmp.name) / "briefs"
        self.herdr = FakeHerdr()
        self.brief = orchestrate.ensure_brief(str(self.repo), "demo", base=self.base)
        fill(self.brief)
        orchestrate.dispatch(str(self.repo), "demo", self.herdr, base=self.base)
        self.wt = Path(self.tmp.name) / "app-demo"

    def tearDown(self):
        self.tmp.cleanup()

    def test_status_lists_state_and_result(self):
        out = orchestrate.status(str(self.repo), self.herdr, base=self.base)
        self.assertIn("demo", out)
        self.assertIn("working", out)
        self.assertIn("結果: 未記入", out)
        Path(self.brief).write_text(Path(self.brief).read_text() + "\n完了した\n")
        self.herdr.agents["app-demo"]["agent_status"] = "done"
        out = orchestrate.status(str(self.repo), self.herdr, base=self.base)
        self.assertIn("done", out)
        self.assertIn("結果: 記入済み", out)

    def test_status_reports_missing_agent(self):
        self.herdr.agents.clear()
        out = orchestrate.status(str(self.repo), self.herdr, base=self.base)
        self.assertIn("不在", out)

    def test_status_without_tasks(self):
        other = make_repo(self.tmp.name, "other")
        self.assertIn("タスクはありません", orchestrate.status(str(other), self.herdr, base=self.base))

    def test_collect_shows_result_and_diff(self):
        Path(self.brief).write_text(Path(self.brief).read_text() + "\nREADME を更新した\n")
        (self.wt / "README.md").write_text("hello\nworld\n")
        git(self.wt, "commit", "-q", "-am", "update readme")
        out = orchestrate.collect(str(self.repo), "demo", base=self.base)
        self.assertIn("README を更新した", out)
        self.assertIn("update readme", out)
        self.assertIn("README.md", out)

    def test_cleanup_removes_worktree_closes_workspace_and_archives(self):
        orchestrate.cleanup(str(self.repo), "demo", self.herdr, base=self.base)
        self.assertFalse(self.wt.exists())
        self.assertEqual(self.herdr.closed, ["w9"])
        self.assertIn("task/demo", git(self.repo, "branch", "--list", "task/demo"))
        self.assertFalse(Path(self.brief).exists())
        archived = list((self.base / "app" / "archive").iterdir())
        self.assertEqual(len(archived), 2)

    def test_cleanup_refuses_dirty_worktree(self):
        (self.wt / "README.md").write_text("dirty\n")
        with self.assertRaises(ValueError):
            orchestrate.cleanup(str(self.repo), "demo", self.herdr, base=self.base)
        self.assertTrue(self.wt.exists())
        self.assertEqual(self.herdr.closed, [])


if __name__ == "__main__":
    unittest.main()
