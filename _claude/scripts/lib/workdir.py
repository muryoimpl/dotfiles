#!/usr/bin/env python3
"""Bash tool のコマンドから「実際にコマンドが走ったディレクトリ」を求める。

settings.json で CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=true にしているため、
Claude が `cd <worktree> && ...` で作業してもセッションの cwd は起動時のまま
変わらない。statusline (claude-powerline) は cwd の branch を出すので、
worktree で作業中でも起動ディレクトリの branch が表示される。

このモジュールはコマンド文字列を軽く解析して実作業ディレクトリを推定し、
~/.claude/state/workdir-<session_id>.txt に記録する。statusline.sh がそれを
読んで実際の branch を 1 行足す。呼び出しは ~/.claude/scripts/track-workdir.sh。

推定ルール:
  - `cd <path>` / `pushd <path>` があれば最後のものを採用 (相対パスは直前の
    ディレクトリ基準、`~` は HOME 展開)
  - cd がなく `git -C <path>` があればその path
  - どちらもなければ cwd
  - path に `$` や `` ` `` を含む (展開できない)、存在しない、`cd -` の場合は cwd
"""

import json
import os
import shlex
import sys
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / "state"

# ここで区切られた各区間の先頭コマンドだけを見る。
_SEPARATORS = {"&&", "||", ";"}
_CD_COMMANDS = {"cd", "pushd"}


def _tokens(command):
    # 改行は `;` と同じ区切りとして扱う。クォート内の改行も置換されるが、
    # cd の対象パスに改行が入ることはないので実害はない
    lexer = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError:
        return []


def _segments(tokens):
    """区切り記号で分割し、各区間のトークン列を返す。パイプの右側は捨てる。"""
    segs, cur = [], []
    for tok in tokens:
        if tok in _SEPARATORS:
            segs.append(cur)
            cur = []
        elif tok == "|":
            # `a | cd x` の cd は別プロセスで cwd に影響しないので区間ごと無視する
            cur.append("|")
        else:
            cur.append(tok)
    segs.append(cur)
    return [s for s in segs if s and "|" not in s]


def _resolve(path, base, home):
    if "$" in path or "`" in path:
        return None
    if path == "~" or path.startswith("~/"):
        path = home + path[1:]
    elif path.startswith("~"):
        return None
    if not os.path.isabs(path):
        path = os.path.join(base, path)
    path = os.path.normpath(path)
    return path if os.path.isdir(path) else None


def _strip_leading(seg):
    while seg and seg[0] in ("(", "{"):
        seg = seg[1:]
    return seg


def effective_dir(command, cwd, home=None):
    home = home or os.path.expanduser("~")
    current = cwd
    git_c = None
    for seg in _segments(_tokens(command or "")):
        seg = _strip_leading(seg)
        if not seg:
            continue
        head = seg[0]
        if head in _CD_COMMANDS:
            args = [a for a in seg[1:] if not a.startswith("-") or a == "-"]
            if not args:
                target = home if os.path.isdir(home) else None
            elif args[0] == "-":
                target = None
            else:
                target = _resolve(args[0], current, home)
            if target is None:
                return cwd
            current = target
        elif head == "git" and git_c is None and len(seg) >= 3 and seg[1] == "-C":
            git_c = _resolve(seg[2], current, home)
    if current != cwd:
        return current
    return git_c or cwd


def record(hook_input, state_dir=STATE_DIR):
    session_id = hook_input.get("session_id")
    cwd = hook_input.get("cwd")
    if not session_id or not cwd:
        return None
    command = (hook_input.get("tool_input") or {}).get("command") or ""
    target = effective_dir(command, cwd)
    state_dir = Path(state_dir)
    state_dir.mkdir(parents=True, exist_ok=True)
    path = state_dir / f"workdir-{session_id}.txt"
    path.write_text(target + "\n", encoding="utf-8")
    return str(path)


def main():
    try:
        hook_input = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0
    if not isinstance(hook_input, dict):
        return 0
    try:
        record(hook_input)
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
