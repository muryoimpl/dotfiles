#!/usr/bin/env python3
"""learning の単体テスト。

実行: python3 ~/.claude/scripts/lib/test_learning.py -v
"""

import datetime
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import learning  # noqa: E402

SAMPLE = """# LEARNING.md

<!-- last-reviewed: 2026-09-15 -->

説明文。

## 失敗と対策

- 2026-09-01: A → B
- 2026-09-10: C → D

## 業務知識

## プロジェクト固有の作法

- 2026-09-12: E

## その他
"""


def git(*args, cwd):
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def write_jsonl(path, records):
    with open(path, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


def user(content, meta=False):
    rec = {"type": "user", "message": {"role": "user", "content": content}}
    if meta:
        rec["isMeta"] = True
    return rec


def tool_result():
    return user([{"type": "tool_result", "tool_use_id": "x", "content": "ok"}])


class TestProjectRoot(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.realpath(self.tmp.name)
        self.repo = os.path.join(self.root, "repo")
        os.makedirs(os.path.join(self.repo, "sub"))
        git("init", "-q", cwd=self.repo)
        git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "init", cwd=self.repo)

    def tearDown(self):
        self.tmp.cleanup()

    def test_リポジトリのトップは自身(self):
        self.assertEqual(learning.project_root(self.repo), self.repo)

    def test_サブディレクトリからはトップに解決する(self):
        self.assertEqual(learning.project_root(os.path.join(self.repo, "sub")), self.repo)

    def test_linked_worktree_からは_main_worktree_に解決する(self):
        wt = os.path.join(self.root, "wt")
        git("worktree", "add", "-q", wt, "-b", "feature", cwd=self.repo)
        self.assertEqual(learning.project_root(wt), self.repo)

    def test_git_管理外は_None(self):
        outside = os.path.join(self.root, "plain")
        os.makedirs(outside)
        self.assertIsNone(learning.project_root(outside))

    def test_存在しないディレクトリは_None(self):
        self.assertIsNone(learning.project_root(os.path.join(self.root, "nope")))


class TestParseLearning(unittest.TestCase):
    def test_項目数と最終レビュー日を読む(self):
        parsed = learning.parse_learning(SAMPLE)
        self.assertEqual(parsed["items"], 3)
        self.assertEqual(parsed["last_reviewed"], datetime.date(2026, 9, 15))

    def test_レビュー未実施は_None(self):
        parsed = learning.parse_learning("# LEARNING.md\n\n<!-- last-reviewed: 未実施 -->\n\n- x\n")
        self.assertEqual(parsed["items"], 1)
        self.assertIsNone(parsed["last_reviewed"])

    def test_マーカーが無くても壊れない(self):
        parsed = learning.parse_learning("")
        self.assertEqual(parsed, {"items": 0, "last_reviewed": None})


class TestReviewDue(unittest.TestCase):
    monday = datetime.date(2026, 9, 21)

    def test_iso_week(self):
        self.assertEqual(learning.iso_week(self.monday), "2026-W39")
        self.assertEqual(learning.iso_week(datetime.date(2026, 9, 20)), "2026-W38")

    def test_stamp_も_last_reviewed_も無ければ実施する(self):
        self.assertTrue(learning.review_due(None, None, self.monday))

    def test_今週の_stamp_があれば実施しない(self):
        self.assertFalse(learning.review_due(None, "2026-W39", self.monday))

    def test_先週の_stamp_なら実施する(self):
        self.assertTrue(learning.review_due(None, "2026-W38", self.monday))

    def test_今週手動レビュー済みなら実施しない(self):
        self.assertFalse(learning.review_due(datetime.date(2026, 9, 21), "2026-W38", self.monday))

    def test_先週レビュー済みで_stamp_無しなら実施する(self):
        self.assertTrue(learning.review_due(datetime.date(2026, 9, 18), None, self.monday))


class TestTranscript(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.tmp.name, "t.jsonl")

    def tearDown(self):
        self.tmp.cleanup()

    def test_文字列とテキスト要素だけを発話として数える(self):
        write_jsonl(self.path, [
            user("こんにちは"),
            tool_result(),
            user([{"type": "text", "text": "続けて"}]),
            user("meta", meta=True),
            {"type": "assistant", "message": {"role": "assistant", "content": []}},
        ])
        self.assertEqual(learning.count_user_prompts(self.path), 2)

    def test_slash_command_と_local_command_出力は数えない(self):
        write_jsonl(self.path, [
            user("<command-name>/model</command-name>\n<command-message>model</command-message>"),
            user("<local-command-stdout>ok</local-command-stdout>"),
        ])
        self.assertEqual(learning.count_user_prompts(self.path), 0)

    def test_壊れた行は無視する(self):
        with open(self.path, "w", encoding="utf-8") as f:
            f.write("not json\n")
            f.write(json.dumps(user("x")) + "\n")
        self.assertEqual(learning.count_user_prompts(self.path), 1)

    def test_存在しないファイルは_0(self):
        self.assertEqual(learning.count_user_prompts(os.path.join(self.tmp.name, "none")), 0)

    def test_直前の発話が_learn_なら検出する(self):
        write_jsonl(self.path, [
            user("作業して"),
            user("<command-name>/learn</command-name>\n<command-message>learn</command-message>"),
            user("<command-name>/exit</command-name>"),
        ])
        self.assertTrue(learning.learn_already_run(self.path))

    def test_learn_review_や無関係な発話では検出しない(self):
        write_jsonl(self.path, [user("<command-name>/learn-review</command-name>"), user("次")])
        self.assertFalse(learning.learn_already_run(self.path))


class TestShouldExtract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = os.path.realpath(self.tmp.name)
        git("init", "-q", cwd=self.repo)
        self.transcript = os.path.join(self.repo, "t.jsonl")
        write_jsonl(self.transcript, [user("お願い")])
        self.hook = {
            "session_id": "sid",
            "cwd": self.repo,
            "transcript_path": self.transcript,
            "reason": "prompt_input_exit",
        }

    def tearDown(self):
        self.tmp.cleanup()

    def test_通常の終了では抽出する(self):
        ok, why = learning.should_extract(self.hook, {})
        self.assertTrue(ok, why)

    def test_clear_logout_resume_でも抽出する(self):
        for reason in ("clear", "logout", "resume"):
            ok, _ = learning.should_extract({**self.hook, "reason": reason}, {})
            self.assertTrue(ok, reason)

    def test_other_では抽出しない(self):
        ok, why = learning.should_extract({**self.hook, "reason": "other"}, {})
        self.assertFalse(ok)
        self.assertIn("reason", why)

    def test_自動実行の子セッションでは抽出しない(self):
        ok, _ = learning.should_extract(self.hook, {learning.AUTO_ENV: "1"})
        self.assertFalse(ok)

    def test_git_管理外では抽出しない(self):
        outside = tempfile.mkdtemp()
        try:
            ok, why = learning.should_extract({**self.hook, "cwd": outside}, {})
            self.assertFalse(ok)
            self.assertIn("git", why)
        finally:
            os.rmdir(outside)

    def test_発話が無ければ抽出しない(self):
        write_jsonl(self.transcript, [tool_result()])
        ok, _ = learning.should_extract(self.hook, {})
        self.assertFalse(ok)

    def test_learn_実行済みなら抽出しない(self):
        write_jsonl(self.transcript, [user("x"), user("<command-name>/learn</command-name>")])
        ok, _ = learning.should_extract(self.hook, {})
        self.assertFalse(ok)

    def test_transcript_が無ければ抽出しない(self):
        ok, _ = learning.should_extract({**self.hook, "transcript_path": "/nope"}, {})
        self.assertFalse(ok)


class TestCommands(unittest.TestCase):
    def test_learn_は同セッションを再開して_skill_を渡す(self):
        cmd = learning.learn_command("sid", "/p/LEARNING.md", {})
        self.assertEqual(cmd[:4], ["claude", "-p", "--resume", "sid"])
        self.assertIn("/learn /p/LEARNING.md", cmd)
        self.assertIn("acceptEdits", cmd)
        self.assertNotIn("--model", cmd)

    def test_review_は新規セッション(self):
        cmd = learning.review_command("/p/LEARNING.md", {learning.MODEL_ENV: "sonnet"})
        self.assertNotIn("--resume", cmd)
        self.assertIn("/learn-review /p/LEARNING.md", cmd)
        self.assertEqual(cmd[cmd.index("--model") + 1], "sonnet")

    def test_子プロセスの環境は_herdr_を落として自動実行印を付ける(self):
        env = learning.child_env({"HERDR_ENV": "1", "HERDR_PANE_ID": "p", "HERDR_SOCKET_PATH": "s", "PATH": "/bin"})
        self.assertEqual(env[learning.AUTO_ENV], "1")
        self.assertEqual(env["PATH"], "/bin")
        for k in learning.HERDR_ENV_KEYS:
            self.assertNotIn(k, env)


class TestSpawnDryRun(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.log = Path(self.tmp.name) / "logs" / "x.log"

    def tearDown(self):
        self.tmp.cleanup()

    def test_dry_run_はコマンドを_log_に書くだけ(self):
        started = learning.spawn(["claude", "-p", "/learn a b"], cwd=self.tmp.name, log_path=self.log,
                                 env={learning.DRY_RUN_ENV: "1"})
        self.assertFalse(started)
        text = self.log.read_text(encoding="utf-8")
        self.assertIn("DRY RUN", text)
        self.assertIn("'/learn a b'", text)

    def test_delay_付きは_sh_で包む(self):
        cmd = learning.with_delay(["claude", "-p"], 3)
        self.assertEqual(cmd[:2], ["sh", "-c"])
        self.assertIn("sleep 3", cmd[2])
        self.assertEqual(cmd[-2:], ["claude", "-p"])


class TestHandleLoad(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.realpath(self.tmp.name)
        self.repo = os.path.join(self.root, "repo")
        os.makedirs(self.repo)
        git("init", "-q", cwd=self.repo)
        self.state = Path(self.root) / "state"
        self.today = datetime.date(2026, 9, 21)
        self.env = {learning.DRY_RUN_ENV: "1"}

    def tearDown(self):
        self.tmp.cleanup()

    def hook(self, source="startup", cwd=None):
        return {"session_id": "sid", "cwd": cwd or self.repo, "source": source, "hook_event_name": "SessionStart"}

    def write_learning(self, text=SAMPLE):
        Path(self.repo, "LEARNING.md").write_text(text, encoding="utf-8")

    def test_ファイルが無ければ何も返さない(self):
        self.assertIsNone(learning.handle_load(self.hook(), self.env, self.state, self.today))

    def test_全文と件数を注入し_systemMessage_で知らせる(self):
        self.write_learning()
        out = learning.handle_load(self.hook(), self.env, self.state, self.today)
        ctx = out["hookSpecificOutput"]["additionalContext"]
        self.assertEqual(out["hookSpecificOutput"]["hookEventName"], "SessionStart")
        self.assertIn("3 項目", ctx)
        self.assertIn("2026-09-15", ctx)
        self.assertIn("- 2026-09-10: C → D", ctx)
        self.assertIn("冒頭に", ctx)
        self.assertIn("3 項目", out["systemMessage"])

    def test_compact_では冒頭宣言を求めない(self):
        self.write_learning()
        out = learning.handle_load(self.hook(source="compact"), self.env, self.state, self.today)
        self.assertNotIn("冒頭に", out["hookSpecificOutput"]["additionalContext"])

    def test_startup_で週が変わっていればレビューを起動して_stamp_を書く(self):
        self.write_learning()
        out = learning.handle_load(self.hook(), self.env, self.state, self.today)
        self.assertIn("背景で開始", out["systemMessage"])
        stamp = self.state / f"review-{learning.state_key(self.repo)}.week"
        self.assertEqual(stamp.read_text(encoding="utf-8").strip(), "2026-W39")
        logs = list((self.state / "logs").glob("*-review-*.log"))
        self.assertEqual(len(logs), 1)
        self.assertIn("/learn-review", logs[0].read_text(encoding="utf-8"))

    def test_同じ週に二度は起動しない(self):
        self.write_learning()
        learning.handle_load(self.hook(), self.env, self.state, self.today)
        out = learning.handle_load(self.hook(), self.env, self.state, self.today)
        self.assertNotIn("背景で開始", out["systemMessage"])
        self.assertEqual(len(list((self.state / "logs").glob("*-review-*.log"))), 1)

    def test_resume_ではレビューを起動しない(self):
        self.write_learning()
        out = learning.handle_load(self.hook(source="resume"), self.env, self.state, self.today)
        self.assertNotIn("背景で開始", out["systemMessage"])
        self.assertFalse((self.state / "logs").exists())

    def test_自動実行の子セッションではレビューを起動しない(self):
        self.write_learning()
        env = {**self.env, learning.AUTO_ENV: "1"}
        out = learning.handle_load(self.hook(), env, self.state, self.today)
        self.assertIn("3 項目", out["systemMessage"])
        self.assertFalse((self.state / "logs").exists())

    def test_git_管理外でも_cwd_の_LEARNING_md_は読む(self):
        plain = os.path.join(self.root, "plain")
        os.makedirs(plain)
        Path(plain, "LEARNING.md").write_text(SAMPLE, encoding="utf-8")
        out = learning.handle_load(self.hook(cwd=plain), self.env, self.state, self.today)
        self.assertIn("3 項目", out["systemMessage"])


class TestHandleExtract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = os.path.realpath(self.tmp.name)
        git("init", "-q", cwd=self.repo)
        self.state = Path(self.repo) / "state"
        self.transcript = os.path.join(self.repo, "t.jsonl")
        write_jsonl(self.transcript, [user("お願い")])
        self.hook = {
            "session_id": "sid",
            "cwd": self.repo,
            "transcript_path": self.transcript,
            "reason": "prompt_input_exit",
            "hook_event_name": "SessionEnd",
        }

    def tearDown(self):
        self.tmp.cleanup()

    def test_条件を満たせば_learn_を起動する(self):
        started = learning.handle_extract(self.hook, {learning.DRY_RUN_ENV: "1"}, self.state)
        self.assertTrue(started)
        logs = list((self.state / "logs").glob("*-learn-*.log"))
        self.assertEqual(len(logs), 1)
        text = logs[0].read_text(encoding="utf-8")
        self.assertIn("--resume sid", text)
        self.assertIn(f"/learn {self.repo}/LEARNING.md", text)

    def test_条件を満たさなければ何もしない(self):
        started = learning.handle_extract({**self.hook, "reason": "other"}, {learning.DRY_RUN_ENV: "1"}, self.state)
        self.assertFalse(started)
        self.assertFalse((self.state / "logs").exists())


class TestPruneLogs(unittest.TestCase):
    def test_古い_log_だけ消す(self):
        with tempfile.TemporaryDirectory() as tmp:
            logs = Path(tmp) / "logs"
            logs.mkdir()
            old = logs / "old.log"
            new = logs / "new.log"
            old.write_text("x")
            new.write_text("y")
            past = (datetime.datetime.now() - datetime.timedelta(days=40)).timestamp()
            os.utime(old, (past, past))
            learning.prune_logs(Path(tmp), keep_days=30)
            self.assertFalse(old.exists())
            self.assertTrue(new.exists())


if __name__ == "__main__":
    unittest.main()
