#!/bin/sh
# プロジェクトごとの LEARNING.md を、セッション開始時に読み込み、終了時に更新する。
#
# サブコマンド:
#   load     SessionStart hook。LEARNING.md を additionalContext で注入し、週が変わって
#            最初の startup なら背景で `claude -p "/learn-review"` を起動する
#   extract  SessionEnd hook。背景で `claude -p --resume <session_id> "/learn"` を起動する
#   path     [dir] の LEARNING.md のパス (main worktree のルート) を表示する
#   review   [dir] の週次レビューを手で起動する
#
# 実体は lib/learning.py。こちらは hook から安全に呼ぶためのガード。
#
# 注意 (load / extract):
#   - load の stdout は Claude のコンテキストに入るので、JSON 以外は何も出さない。
#     python の例外は hook-error.log に落とす
#   - 必ず exit 0 すること。非 0 はセッション開始をブロックしうる
#   - SessionEnd の hook 予算は短い (既定 1.5 秒)。extract は背景起動だけして即 exit する

CMD="${1:-}"
[ -n "$CMD" ] || { echo "usage: $0 {load|extract|path [dir]|review [dir]}" >&2; exit 1; }
shift

IMPL="$(dirname "$0")/lib/learning.py"
ERR_LOG="$HOME/.claude/state/learning/hook-error.log"

case "$CMD" in
  load | extract)
    command -v python3 >/dev/null 2>&1 || exit 0
    mkdir -p "$(dirname "$ERR_LOG")" 2>/dev/null
    if [ "$CMD" = "load" ]; then
      python3 "$IMPL" load 2>>"$ERR_LOG" || true
    else
      python3 "$IMPL" extract >/dev/null 2>>"$ERR_LOG" || true
    fi
    exit 0
    ;;
  path | review)
    command -v python3 >/dev/null 2>&1 || { echo "python3 が見つかりません" >&2; exit 1; }
    exec python3 "$IMPL" "$CMD" "$@"
    ;;
  *)
    echo "unknown subcommand: $CMD" >&2
    exit 1
    ;;
esac
