#!/bin/sh
# PostToolUse hook (Bash matcher): 直前の Bash コマンドが実際に走ったディレクトリを
# ~/.claude/state/workdir-<session_id>.txt に記録する。
#
# CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=true のためセッションの cwd は動かず、
# `cd <worktree> && ...` で作業中でも statusline は起動ディレクトリの branch を
# 出してしまう。statusline.sh がこの state を読んで実際の branch を 1 行足す。
#
# 実体は lib/workdir.py。stdout には何も出さず、必ず exit 0 する。
command -v python3 >/dev/null 2>&1 || exit 0
python3 "$(dirname "$0")/lib/workdir.py" >/dev/null 2>&1
exit 0
