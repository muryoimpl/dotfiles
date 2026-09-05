#!/usr/bin/env python3
"""テキストから Linear の issue ID (例 ABC-123) を 1 つ取り出す。

herdr のタブラベル / pane metadata に「いまどの Linear タスクをやっているか」を
固定表示するために使う。呼び出し元は ~/.claude/scripts/herdr-task.sh と
~/.claude/scripts/claude-in-herdr.sh。

チームキーの allowlist (~/.claude/linear-teams.txt) を一次設定とする。
allowlist があれば、そこに書いたキーだけを issue ID として認識するため
"UTF-8" や "ISO-8601" のような誤検出が構造的に起きない。

CLI としても使える:
    echo "ABC-123 を対応" | python3 extract_issue.py
    git branch --show-current | python3 extract_issue.py --ignore-case --cwd /path/to/repo
    python3 extract_issue.py --print-teams
"""

import argparse
import os
import re
import sys
from pathlib import Path

# allowlist の探索先。テストから差し替えられるようモジュール変数にしている。
GLOBAL_TEAMS_FILE = Path.home() / ".claude" / "linear-teams.txt"
PROJECT_TEAMS_RELPATH = Path(".claude") / "linear-teams.txt"
ENV_TEAMS = "LINEAR_TEAM_KEYS"

# チームキーは 2〜10 文字、issue 番号は 6 桁まで。
# 前後が英数字なら境界とみなさない ("XABC-123" の "ABC" を拾わない)。
# 絞り込みは allowlist に任せるので、パターン自体は広めに取る。
ISSUE_RE = re.compile(r"(?<![A-Za-z0-9])([A-Za-z][A-Za-z0-9]{1,9})-([0-9]{1,6})(?![0-9])")

# allowlist が未設定のときだけ使うフォールバック。
# issue ID に見えるが実際には規格名・文字コード名であるものを弾く。
DENY_KEYS = frozenset(
    """
    UTF UTF8 ISO RFC CVE CWE SHA MD HTTP HTTPS IPV IP TCP UDP TLS SSL
    ES ECMA ANSI ASCII EUC UCS JIS PEP RGB RGBA SRGB HSL CMYK
    AES RSA HMAC JWT OAUTH SAML LDAP SMTP IMAP POP FTP SSH
    PNG JPEG GIF SVG PDF CSV TSV XML JSON YAML TOML INI
    X86 ARM AMD GTK QT KDE USB PCI SATA NVME DDR
    GPT LLM API SDK CLI GUI TUI URL URI UUID GUID
    """.split()
)


def _dedupe(keys):
    """順序を保ったまま重複を落とす。"""
    seen = set()
    out = []
    for key in keys:
        if key and key not in seen:
            seen.add(key)
            out.append(key)
    return out


def _parse_teams(text):
    """allowlist の本文をパースする。# 以降はコメント、空行は無視、大文字化する。"""
    keys = []
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            keys.append(line.upper())
    return keys


def _read_teams_file(path):
    try:
        return _parse_teams(Path(path).read_text(encoding="utf-8"))
    except OSError:
        return []


def _repo_root(cwd):
    """cwd から上に辿って .git を持つディレクトリを探す。

    git worktree では .git がファイルなので exists() で判定する。
    hook から毎プロンプト呼ばれる経路なので subprocess は使わない。
    """
    try:
        current = Path(cwd or os.getcwd()).resolve()
    except OSError:
        return None
    for directory in (current, *current.parents):
        if (directory / ".git").exists():
            return directory
    return None


def load_teams(cwd=None):
    """チームキーの allowlist を読む。

    優先順:
      1. 環境変数 LINEAR_TEAM_KEYS (カンマ区切り) — 指定時はこれだけを使う
      2. ~/.claude/linear-teams.txt と <repo>/.claude/linear-teams.txt の和集合
      3. どちらも無ければ空リスト (呼び出し側は DENY セットにフォールバックする)
    """
    env = os.environ.get(ENV_TEAMS, "")
    if env.strip():
        return _dedupe(_parse_teams(env.replace(",", "\n")))

    keys = _read_teams_file(GLOBAL_TEAMS_FILE)
    root = _repo_root(cwd)
    if root is not None:
        keys += _read_teams_file(root / PROJECT_TEAMS_RELPATH)
    return _dedupe(keys)


def extract(text, teams=None, ignore_case=False):
    """text から issue ID を 1 つ返す。見つからなければ None。

    teams に allowlist を渡すと、そのチームキーのものだけを採用する。
    空または None の場合は DENY セットで明らかな誤検出だけを弾く。
    ignore_case=True はブランチ名・ディレクトリ名向け (abc-123 → ABC-123)。
    """
    if not text:
        return None

    allow = {key.upper() for key in teams} if teams else None

    for match in ISSUE_RE.finditer(text):
        key_raw, number = match.group(1), match.group(2)
        # ignore_case でないなら、元テキストが大文字であることを要求する
        if not ignore_case and key_raw != key_raw.upper():
            continue
        key = key_raw.upper()
        if allow is not None:
            if key not in allow:
                continue
        elif key in DENY_KEYS:
            continue
        return "{}-{}".format(key, number)
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ignore-case",
        action="store_true",
        help="小文字のチームキーも拾う (ブランチ名・ディレクトリ名向け)",
    )
    parser.add_argument("--cwd", default=None, help="allowlist 探索の起点ディレクトリ")
    parser.add_argument(
        "--print-teams",
        action="store_true",
        help="読み込んだ allowlist を表示して終了する",
    )
    args = parser.parse_args(argv)

    teams = load_teams(cwd=args.cwd)

    if args.print_teams:
        if teams:
            print("\n".join(teams))
        else:
            print(
                "allowlist 未設定 (~/.claude/linear-teams.txt)。"
                "DENY セットによるヒューリスティックで動作します。",
                file=sys.stderr,
            )
        return 0

    try:
        text = sys.stdin.read()
    except (OSError, UnicodeDecodeError):
        return 0

    issue = extract(text, teams=teams, ignore_case=args.ignore_case)
    if issue:
        print(issue)
    return 0


if __name__ == "__main__":
    sys.exit(main())
