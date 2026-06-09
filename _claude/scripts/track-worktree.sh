#!/usr/bin/env bash
# PostToolUse hook (Bash matcher): record/remove current worktree path per session.
# State file: ~/.claude/state/worktree-<session_id>.txt

set -u

INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""')"
[ -z "$SESSION_ID" ] && exit 0

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // ""')"
EXIT_CODE="$(printf '%s' "$INPUT" | jq -r '.tool_response.exit_code // .tool_response.exitCode // 0')"

[ "$EXIT_CODE" != "0" ] && exit 0

STATE_DIR="$HOME/.claude/state"
STATE_FILE="$STATE_DIR/worktree-${SESSION_ID}.txt"
mkdir -p "$STATE_DIR"

extract_path_after_add() {
  python3 - "$1" <<'PY' 2>/dev/null
import shlex, sys
cmd = sys.argv[1]
try:
    parts = shlex.split(cmd)
except ValueError:
    sys.exit(0)
for i in range(len(parts) - 1):
    if parts[i] == "worktree" and parts[i+1] in ("add", "remove"):
        sub = parts[i+1]
        j = i + 2
        while j < len(parts):
            p = parts[j]
            if p.startswith("-"):
                if p in ("-b", "-B"):
                    j += 2
                    continue
                j += 1
                continue
            print(f"{sub}\t{p}")
            sys.exit(0)
        break
PY
}

resolve_abs() {
  local path="$1" base="$2"
  case "$path" in
    /*) printf '%s' "$path" ;;
    *)
      local dir base_name
      dir="$(dirname "$path")"
      base_name="$(basename "$path")"
      (cd "$base" 2>/dev/null && cd "$dir" 2>/dev/null && printf '%s/%s' "$(pwd)" "$base_name")
      ;;
  esac
}

case "$CMD" in
  *"git worktree add"*|*"git worktree remove"*)
    RESULT="$(extract_path_after_add "$CMD")"
    [ -z "$RESULT" ] && exit 0
    SUB="${RESULT%%	*}"
    REL_PATH="${RESULT#*	}"
    ABS_PATH="$(resolve_abs "$REL_PATH" "$CWD")"
    [ -z "$ABS_PATH" ] && exit 0

    if [ "$SUB" = "add" ]; then
      printf '%s\n' "$ABS_PATH" > "$STATE_FILE"
    elif [ "$SUB" = "remove" ]; then
      if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$ABS_PATH" ]; then
        rm -f "$STATE_FILE"
      fi
    fi
    ;;
esac

exit 0
