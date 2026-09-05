#!/bin/sh
# claude のセッションに Linear の issue ID を紐付け、herdr の tab / sidebar に固定表示する。
#
# 同じ workspace に claude のタブを複数開くと、herdr のタブラベルが全て "claude" に
# なって「どのタブがどのタスクか」が分からなくなる。herdr のタブラベルは custom_name か
# 位置番号の 2 択で cwd もプロセス名も OSC も見ないため、外から CLI で補う。
#
# サブコマンド:
#   label   UserPromptSubmit hook。issue ID を確定して tab / pane に反映する
#   done    Stop hook。CLAUDE.md の完了の合い言葉を検出したら "✓" を付ける
#   set     issue ID を手で上書きする (誤検出時・自動検出できなかったとき)
#   list    いまどこでどのタスクが走っているかを一覧する
#
# 実体は lib/herdr_task.py。こちらは hook から安全に呼ぶためのガード。
#
# 注意 (label / done):
#   - stdout に何も出力しないこと。UserPromptSubmit の stdout は Claude のコンテキストに
#     追加されるため、例外時のメッセージも含めてすべて捨てる
#   - 必ず exit 0 すること。非 0 (特に 2) はプロンプト送信自体をブロックする

CMD="${1:-}"
[ -n "$CMD" ] || { echo "usage: $0 {label|done|set <ISSUE>|list}" >&2; exit 1; }
shift

IMPL="$(dirname "$0")/lib/herdr_task.py"

case "$CMD" in
  label | done)
    # herdr の外・python3 が無い環境では何もしない
    [ "${HERDR_ENV:-}" = "1" ] || exit 0
    [ -n "${HERDR_PANE_ID:-}" ] || exit 0
    command -v python3 >/dev/null 2>&1 || exit 0
    python3 "$IMPL" "$CMD" >/dev/null 2>&1
    exit 0
    ;;
  set | list)
    command -v python3 >/dev/null 2>&1 || { echo "python3 が見つかりません" >&2; exit 1; }
    exec python3 "$IMPL" "$CMD" "$@"
    ;;
  *)
    echo "unknown subcommand: $CMD" >&2
    exit 1
    ;;
esac
