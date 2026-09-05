#!/usr/bin/env python3
"""extract_issue の単体テスト。

実行: python3 ~/.claude/scripts/lib/test_extract_issue.py -v
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import extract_issue  # noqa: E402


class TestExtract(unittest.TestCase):
    """allowlist ありの抽出 (本番の既定経路)。"""

    def test_プロンプト本文から拾う(self):
        self.assertEqual(
            extract_issue.extract("ABC-123 のログイン修正をお願いします", teams=["ABC"]),
            "ABC-123",
        )

    def test_allowlist_にあっても大文字小文字が違えば拾わない(self):
        self.assertIsNone(
            extract_issue.extract("abc-123-fix-login", teams=["ABC"])
        )

    def test_ignore_case_ならブランチ名からも拾い大文字に正規化する(self):
        self.assertEqual(
            extract_issue.extract("abc-123-fix-login", teams=["ABC"], ignore_case=True),
            "ABC-123",
        )

    def test_ブランチのスラッシュ区切りでも拾う(self):
        self.assertEqual(
            extract_issue.extract("feature/ABC-1234-foo", teams=["ABC"], ignore_case=True),
            "ABC-1234",
        )

    def test_allowlist_外のチームキーは採用しない(self):
        self.assertIsNone(extract_issue.extract("DEF-1 を対応", teams=["ABC"]))

    def test_allowlist_があれば文字コード名を誤検出しない(self):
        self.assertIsNone(
            extract_issue.extract("UTF-8 のエンコーディング問題", teams=["ABC"])
        )

    def test_複数ある場合は最初のものを採る(self):
        self.assertEqual(
            extract_issue.extract("ABC-123 と XYZ-9 の両方", teams=["ABC", "XYZ"]),
            "ABC-123",
        )

    def test_後ろにある方だけが_allowlist_にあるならそれを採る(self):
        self.assertEqual(
            extract_issue.extract("UTF-8 と ABC-123", teams=["ABC"]),
            "ABC-123",
        )


class TestExtractWithoutAllowlist(unittest.TestCase):
    """allowlist 未設定時の DENY セットによるフォールバック。"""

    def test_文字コード名を弾く(self):
        self.assertIsNone(extract_issue.extract("UTF-8 のエンコーディング問題", teams=[]))

    def test_規格番号を弾く(self):
        self.assertIsNone(extract_issue.extract("ISO-8601 形式で", teams=[]))
        self.assertIsNone(extract_issue.extract("RFC-2119 に従う", teams=[]))

    def test_それらしいものは拾う(self):
        self.assertEqual(extract_issue.extract("ABC-123 を対応", teams=[]), "ABC-123")

    def test_teams_が_None_でも_DENY_フォールバックになる(self):
        self.assertIsNone(extract_issue.extract("UTF-8 の話", teams=None))


class TestExtractNoMatch(unittest.TestCase):
    def test_空文字(self):
        self.assertIsNone(extract_issue.extract("", teams=["ABC"]))

    def test_バージョン番号は拾わない(self):
        self.assertIsNone(extract_issue.extract("リリース v1.2.3", teams=["ABC"]))

    def test_数字が長すぎるものは拾わない(self):
        self.assertIsNone(extract_issue.extract("ABC-1234567 は別物", teams=["ABC"]))

    def test_英数字が続く場合は境界とみなさない(self):
        self.assertIsNone(extract_issue.extract("XABC-123", teams=["ABC"]))


class TestLoadTeams(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self._env_backup = os.environ.get("LINEAR_TEAM_KEYS")
        os.environ.pop("LINEAR_TEAM_KEYS", None)
        # グローバル側の探索先をテスト用に差し替える
        self._orig_global = extract_issue.GLOBAL_TEAMS_FILE
        extract_issue.GLOBAL_TEAMS_FILE = self.tmp / "global" / "linear-teams.txt"

    def tearDown(self):
        extract_issue.GLOBAL_TEAMS_FILE = self._orig_global
        if self._env_backup is None:
            os.environ.pop("LINEAR_TEAM_KEYS", None)
        else:
            os.environ["LINEAR_TEAM_KEYS"] = self._env_backup
        self._tmp.cleanup()

    def _write(self, path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding="utf-8")

    def test_どこにも無ければ空リスト(self):
        self.assertEqual(extract_issue.load_teams(cwd=str(self.tmp)), [])

    def test_グローバルファイルを読む(self):
        self._write(extract_issue.GLOBAL_TEAMS_FILE, "ABC\nXYZ\n")
        self.assertEqual(extract_issue.load_teams(cwd=str(self.tmp)), ["ABC", "XYZ"])

    def test_コメントと空行と前後の空白を無視し大文字化する(self):
        self._write(
            extract_issue.GLOBAL_TEAMS_FILE,
            "# コメント\n\n  abc  \nxyz # 行末コメント\n",
        )
        self.assertEqual(extract_issue.load_teams(cwd=str(self.tmp)), ["ABC", "XYZ"])

    def test_プロジェクト側とグローバル側は和集合になる(self):
        self._write(extract_issue.GLOBAL_TEAMS_FILE, "ABC\n")
        repo = self.tmp / "repo"
        (repo / ".git").mkdir(parents=True)
        self._write(repo / ".claude" / "linear-teams.txt", "DEF\nABC\n")
        self.assertEqual(sorted(extract_issue.load_teams(cwd=str(repo))), ["ABC", "DEF"])

    def test_環境変数が最優先でファイルを無視する(self):
        self._write(extract_issue.GLOBAL_TEAMS_FILE, "ABC\n")
        os.environ["LINEAR_TEAM_KEYS"] = "def, ghi"
        self.assertEqual(extract_issue.load_teams(cwd=str(self.tmp)), ["DEF", "GHI"])


if __name__ == "__main__":
    unittest.main()
