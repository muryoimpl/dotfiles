#!/usr/bin/env bash
# PostToolUse (Bash) hook: git worktree add の成功を検知したら、tmux 新 window で別 claude を起動し、
# 直前のユーザープロンプトを送信して worktree での作業を委譲する。
# track-worktree.sh の後に走る前提で、~/.claude/state/worktree-<session_id>.txt を再利用する。
set -u

INPUT=$(cat)

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""')
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
EXIT_CODE=$(printf '%s' "$INPUT" | jq -r '.tool_response.exit_code // .tool_response.exitCode // 0')

[ "$EXIT_CODE" = "0" ] || exit 0
[ -n "$SESSION_ID" ] || exit 0
case "$CMD" in
  *"git worktree add"*) ;;
  *) exit 0 ;;
esac

STATE_FILE="$HOME/.claude/state/worktree-${SESSION_ID}.txt"
[ -f "$STATE_FILE" ] || exit 0
WT_PATH=$(cat "$STATE_FILE")
[ -n "$WT_PATH" ] && [ -d "$WT_PATH" ] || exit 0

PROMPT_LOG="$HOME/.claude/prompt_history.jsonl"
TASK=""
if [ -f "$PROMPT_LOG" ]; then
  TASK=$(jq -r --arg sid "$SESSION_ID" \
    'select(.session_id == $sid) | select((.prompt // "") != "") | .prompt' \
    "$PROMPT_LOG" 2>/dev/null | tail -n 1)
fi

NAME=$(~/.claude/scripts/claude-in-new-window.sh "$WT_PATH" "$TASK" 2>/dev/null) || exit 0

cat <<EOF
[hook: on-worktree-add] worktree "$WT_PATH" 向けの作業は tmux window "$NAME" の別 claude セッションに委譲しました。
直前のユーザープロンプトを新 window に送信済みです。
このセッションでは以降 worktree 内の追加作業を行わず、その旨を 1〜2 行でユーザーに報告して turn を終了してください。
EOF
exit 0
