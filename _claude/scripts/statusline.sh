#!/usr/bin/env bash
# statusLine wrapper: prepend worktree info line to claude-powerline output.

set -u

INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""')"
PROJECT_DIR="$(printf '%s' "$INPUT" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // ""')"

STATE_FILE="$HOME/.claude/state/worktree-${SESSION_ID}.txt"
WORKTREE=""
if [ -n "$SESSION_ID" ] && [ -f "$STATE_FILE" ]; then
  WORKTREE="$(cat "$STATE_FILE")"
fi

POWERLINE_OUT="$(printf '%s' "$INPUT" | npx -y @owloops/claude-powerline@latest)"

if [ -n "$WORKTREE" ] && [ -d "$WORKTREE" ]; then
  PROJECT_NAME="$(basename "$PROJECT_DIR")"
  WORKTREE_NAME="$(basename "$WORKTREE")"
  if [ "$PROJECT_NAME" != "$WORKTREE_NAME" ]; then
    printf '\033[1;36m📂 %s | wt: %s\033[0m\n%s\n' "$PROJECT_NAME" "$WORKTREE_NAME" "$POWERLINE_OUT"
    exit 0
  fi
fi

printf '%s\n' "$POWERLINE_OUT"
