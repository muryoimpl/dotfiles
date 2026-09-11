#!/usr/bin/env bash
# statusLine wrapper: claude-powerline の出力の上に、必要なときだけ 1 行足す。
#
# 1. 実作業ディレクトリの branch (track-workdir.sh が記録した state)
#    CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=true のため、`cd <worktree> && ...` で
#    作業していてもセッションの cwd は起動ディレクトリのまま。powerline はその cwd の
#    branch を出すので、実際に作業しているディレクトリの branch を別に表示する。
# 2. このセッションで作った worktree (track-worktree.sh が記録した state)
#    1. が出ないときだけ従来どおり "📂 project | wt: name" を出す。

set -u

INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""')"
CURRENT_DIR="$(printf '%s' "$INPUT" | jq -r '.workspace.current_dir // .cwd // ""')"
PROJECT_DIR="$(printf '%s' "$INPUT" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // ""')"

STATE_DIR="$HOME/.claude/state"
POWERLINE_OUT="$(printf '%s' "$INPUT" | npx -y @owloops/claude-powerline@latest)"

# 1. 実作業ディレクトリが cwd と違えば、その branch を出す
WORKDIR_FILE="$STATE_DIR/workdir-${SESSION_ID}.txt"
if [ -n "$SESSION_ID" ] && [ -f "$WORKDIR_FILE" ]; then
  WORKDIR="$(cat "$WORKDIR_FILE")"
  if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ] && [ -d "$CURRENT_DIR" ] \
     && [ "$(realpath "$WORKDIR")" != "$(realpath "$CURRENT_DIR")" ]; then
    BRANCH="$(git -C "$WORKDIR" branch --show-current 2>/dev/null)"
    if [ -z "$BRANCH" ] && git -C "$WORKDIR" rev-parse --git-dir >/dev/null 2>&1; then
      BRANCH="$(git -C "$WORKDIR" rev-parse --short HEAD 2>/dev/null)"
    fi
    if [ -n "$BRANCH" ]; then
      DIRTY=""
      git -C "$WORKDIR" diff --quiet HEAD -- 2>/dev/null || DIRTY=" *"
      printf '\033[1;33m📂 %s ⎇ %s%s\033[0m\n%s\n' "$(basename "$WORKDIR")" "$BRANCH" "$DIRTY" "$POWERLINE_OUT"
      exit 0
    fi
  fi
fi

# 2. このセッションで作った worktree
WORKTREE_FILE="$STATE_DIR/worktree-${SESSION_ID}.txt"
if [ -n "$SESSION_ID" ] && [ -f "$WORKTREE_FILE" ]; then
  WORKTREE="$(cat "$WORKTREE_FILE")"
  if [ -n "$WORKTREE" ] && [ -d "$WORKTREE" ]; then
    PROJECT_NAME="$(basename "$PROJECT_DIR")"
    WORKTREE_NAME="$(basename "$WORKTREE")"
    if [ "$PROJECT_NAME" != "$WORKTREE_NAME" ]; then
      printf '\033[1;36m📂 %s | wt: %s\033[0m\n%s\n' "$PROJECT_NAME" "$WORKTREE_NAME" "$POWERLINE_OUT"
      exit 0
    fi
  fi
fi

printf '%s\n' "$POWERLINE_OUT"
