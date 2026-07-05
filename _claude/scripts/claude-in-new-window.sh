#!/usr/bin/env bash
# tmux の新しい window を作成し、指定ディレクトリで claude を起動、任意の task 文字列を送信する。
# 使い方: claude-in-new-window.sh <dir> [<task>]
# 成功時は stdout に作成した window 名を出力する。
set -u

DIR="${1:-}"
TASK="${2:-}"

if [ -z "$DIR" ]; then
  echo "usage: $0 <dir> [<task>]" >&2
  exit 1
fi

command -v tmux >/dev/null || { echo "tmux が見つかりません" >&2; exit 1; }
tmux display-message -p '#S' >/dev/null 2>&1 || { echo "tmux セッション外です" >&2; exit 1; }
[ -d "$DIR" ] || { echo "ディレクトリなし: $DIR" >&2; exit 1; }

DIR=$(cd "$DIR" && pwd)

NAME=$(basename "$DIR")
n=2
while tmux list-windows -F '#W' | grep -qx "$NAME"; do
  NAME="$(basename "$DIR")-$n"
  n=$((n+1))
done

tmux new-window -c "$DIR" -n "$NAME"
tmux send-keys -t "$NAME" 'claude' Enter

# claude 起動待ち。環境によっては 3 秒で足りない場合があるので必要なら値を上げる。
sleep 3

if [ -n "$TASK" ]; then
  # 複数行 / クォート / バックスラッシュを安全に扱うため load-buffer + paste-buffer を使う。
  printf '%s' "$TASK" | tmux load-buffer -
  tmux paste-buffer -t "$NAME"
  tmux send-keys -t "$NAME" Enter
fi

echo "$NAME"
