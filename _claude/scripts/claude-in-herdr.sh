#!/usr/bin/env bash
# herdr で <dir> 用の workspace を作り、claude を起動して任意の task 文字列を送信する。
# tmux 版 (claude-in-new-window.sh) の herdr 相当。
# 使い方: claude-in-herdr.sh <dir> [<task>]
# 成功時は stdout に作成した agent 名を出力する。
set -u

DIR="${1:-}"
TASK="${2:-}"

if [ -z "$DIR" ]; then
  echo "usage: $0 <dir> [<task>]" >&2
  exit 1
fi

[ "${HERDR_ENV:-}" = "1" ] || { echo "herdr セッション外です" >&2; exit 1; }
command -v herdr >/dev/null || { echo "herdr が見つかりません" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq が見つかりません" >&2; exit 1; }
[ -d "$DIR" ] || { echo "ディレクトリなし: $DIR" >&2; exit 1; }

DIR=$(cd "$DIR" && pwd)
LABEL=$(basename "$DIR")

# agent 名は [a-z][a-z0-9_-]{0,31} に一致し、live agent 間で一意である必要がある。
BASE=$(printf '%s' "$LABEL" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_-' '-' | cut -c1-30)
case "$BASE" in
  [a-z]*) ;;
  *) BASE="a$BASE" ;;
esac
NAME="$BASE"
n=2
while herdr agent get "$NAME" >/dev/null 2>&1; do
  NAME="$BASE-$n"
  n=$((n + 1))
done

# workspace 単位で切ることで sidebar の状態ロールアップ (blocked/done) が効く。
created=$(herdr workspace create --cwd "$DIR" --label "$LABEL" --no-focus) || exit 1
PANE=$(printf '%s' "$created" | jq -r '.result.root_pane.pane_id')
[ -n "$PANE" ] && [ "$PANE" != "null" ] || { echo "pane_id を取得できませんでした" >&2; exit 1; }

# agent start は「対話プロンプトに戻っている shell pane」を要求するが、
# workspace create は shell の初期化完了を待たずに返る。
# そのため agent_pane_busy の間だけリトライする (他のエラーは即座に中断)。
# claude の起動待ちは agent start 自身が行うので tmux 版の sleep 3 は不要。
deadline=$((SECONDS + 30))
while :; do
  err=$(herdr agent start "$NAME" --kind claude --pane "$PANE" 2>&1 >/dev/null) && break
  case "$err" in
    *agent_pane_busy*)
      if [ "$SECONDS" -ge "$deadline" ]; then
        echo "shell の準備待ちでタイムアウトしました: $err" >&2
        exit 1
      fi
      sleep 0.5
      ;;
    *)
      echo "$err" >&2
      exit 1
      ;;
  esac
done

if [ -n "$TASK" ]; then
  # agent start は「入力可能」を検出した時点で返るが、claude の TUI は
  # その直後に承認ダイアログを描くことがある。未訪問のディレクトリでは
  # "Is this a project you trust?" が出て blocked になり、そこへ task を
  # 送ると本文はダイアログに吸われ Enter が「信頼する」を選んでしまう。
  # 描画が落ち着くのを待ってから状態を確認する。
  sleep 2

  STATE=$(herdr agent get "$NAME" 2>/dev/null | jq -r '.result.agent.agent_status // "unknown"')
  case "$STATE" in
    idle | done) ;;
    *)
      echo "$NAME"
      echo "agent \"$NAME\" は $STATE のため task を送信していません。" \
           "承認ダイアログに応答してから herdr agent prompt $NAME '<task>' を実行してください。" >&2
      exit 3
      ;;
  esac

  # 送信されたことを画面で実地確認するための needle。
  # TASK 先頭行の先頭 24 文字を使う (折り返しを避けるため短く取る)。
  NEEDLE=$(printf '%s' "$TASK" | head -n 1 | cut -c1-24)

  # bracketed paste モードを尊重した atomic 送信。
  # tmux 版の load-buffer + paste-buffer + Enter に相当する。
  # --wait は non-working から 5 秒以内に状態遷移が観測できないと
  # agent_prompt_stalled を返す。--timeout は 5000 より大きくしないと
  # 通常の timeout に化けるため 6000 にしている。
  send_prompt() {
    err=$(herdr agent prompt "$NAME" "$TASK" --wait --timeout 6000 2>&1 >/dev/null) || true
    case "$err" in
      "" | *timeout* | *agent_prompt_stalled*) ;;
      *) echo "$err" >&2; return 1 ;;
    esac
    # 状態遷移だけでは「ダイアログに吸われた」を見抜けないので、
    # プロンプトが実際に画面へ現れたかどうかで判定する。
    herdr pane wait-output "$PANE" --match "$NEEDLE" \
      --source recent-unwrapped --timeout 6000 >/dev/null 2>&1
  }

  if ! send_prompt; then
    if ! send_prompt; then
      echo "$NAME"
      echo "agent \"$NAME\" を起動しましたが task の送信を確認できませんでした。" \
           "herdr agent read $NAME で画面を確認してください。" >&2
      exit 3
    fi
  fi
fi

echo "$NAME"
