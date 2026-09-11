#!/usr/bin/env python3
"""workdir の単体テスト。

実行: python3 ~/.claude/scripts/lib/test_workdir.py -v
"""

import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import workdir  # noqa: E402


class TestEffectiveDir(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        self.home = os.path.join(self.root, "home")
        self.cwd = os.path.join(self.root, "proj")
        self.wt = os.path.join(self.root, "wt")
        for d in (self.home, self.cwd, self.wt, os.path.join(self.cwd, "sub")):
            os.makedirs(d)

    def tearDown(self):
        self.tmp.cleanup()

    def eff(self, command):
        return workdir.effective_dir(command, self.cwd, home=self.home)

    def test_cd_しないコマンドは_cwd(self):
        self.assertEqual(self.eff("ls -la && git status"), self.cwd)

    def test_絶対パスへの_cd(self):
        self.assertEqual(self.eff(f"cd {self.wt} && git status"), self.wt)

    def test_相対パスへの_cd_は_cwd_基準で解決する(self):
        self.assertEqual(self.eff("cd sub && ls"), os.path.join(self.cwd, "sub"))

    def test_チルダは_home_に展開する(self):
        os.makedirs(os.path.join(self.home, "x"))
        self.assertEqual(self.eff("cd ~/x && ls"), os.path.join(self.home, "x"))

    def test_引数なしの_cd_は_home(self):
        self.assertEqual(self.eff("cd && ls"), self.home)

    def test_クォートされたパス(self):
        spaced = os.path.join(self.root, "with space")
        os.makedirs(spaced)
        self.assertEqual(self.eff(f'cd "{spaced}" && ls'), spaced)
        self.assertEqual(self.eff(f"cd '{spaced}'; ls"), spaced)

    def test_変数を含むパスは解決できないので_cwd(self):
        self.assertEqual(self.eff('cd "$D" && ls'), self.cwd)
        self.assertEqual(self.eff("cd $HOME/x && ls"), self.cwd)

    def test_cd_ハイフンは_cwd(self):
        self.assertEqual(self.eff("cd - && ls"), self.cwd)

    def test_存在しないディレクトリへの_cd_は_cwd(self):
        self.assertEqual(self.eff(f"cd {self.root}/nope && ls"), self.cwd)

    def test_複数回の_cd_は最後が勝つ(self):
        self.assertEqual(self.eff(f"cd {self.wt} && cd .. && cd proj/sub && ls"),
                         os.path.join(self.cwd, "sub"))

    def test_サブシェルの先頭括弧を無視する(self):
        self.assertEqual(self.eff(f"( cd {self.wt} && make )"), self.wt)

    def test_git_C_のパス(self):
        self.assertEqual(self.eff(f"git -C {self.wt} log --oneline -3"), self.wt)

    def test_cd_があれば_git_C_より_cd_を優先する(self):
        self.assertEqual(self.eff(f"cd {self.wt} && git -C {self.cwd} status"), self.wt)

    def test_途中の_cd_も拾う(self):
        self.assertEqual(self.eff(f"export X=1; cd {self.wt} && make"), self.wt)

    def test_パイプの後ろの_cd_は無視する(self):
        # `echo x | cd y` のような形は実質 cd されないので cwd のまま
        self.assertEqual(self.eff(f"echo x | cd {self.wt}"), self.cwd)

    def test_改行区切りでも_cd_を拾う(self):
        self.assertEqual(self.eff(f"cd {self.wt}\nls -la"), self.wt)

    def test_ヒアドキュメントを含んでも先頭の_cd_を拾う(self):
        self.assertEqual(self.eff(f"cd {self.wt} && cat > f <<'EOF'\nhello \"x\"\nEOF"), self.wt)

    def test_空コマンド(self):
        self.assertEqual(self.eff(""), self.cwd)

    def test_閉じていないクォートでも落ちない(self):
        self.assertEqual(self.eff("echo 'unterminated"), self.cwd)


class TestRecord(unittest.TestCase):
    def test_hook_入力から_state_を書く(self):
        with tempfile.TemporaryDirectory() as tmp:
            wt = os.path.join(tmp, "wt")
            os.makedirs(wt)
            state_dir = os.path.join(tmp, "state")
            hook = {
                "session_id": "sess-1",
                "cwd": tmp,
                "tool_input": {"command": f"cd {wt} && ls"},
            }
            path = workdir.record(hook, state_dir=state_dir)
            self.assertEqual(path, os.path.join(state_dir, "workdir-sess-1.txt"))
            with open(path, encoding="utf-8") as f:
                self.assertEqual(f.read(), wt + "\n")

    def test_session_id_がなければ何もしない(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(workdir.record({"cwd": tmp, "tool_input": {"command": "ls"}},
                                             state_dir=os.path.join(tmp, "state")))
            self.assertFalse(os.path.exists(os.path.join(tmp, "state")))


if __name__ == "__main__":
    unittest.main()
