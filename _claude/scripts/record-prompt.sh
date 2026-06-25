#!/bin/bash
# UserPromptSubmit フック: プロンプト内容とセッション ID を記録する。
# 誤って Ctrl+C 等で終了した場合に `claude --resume <session_id>` で再開できるようにする。
set -euo pipefail

LOG_DIR="$HOME/.claude"
JSONL="$LOG_DIR/prompt_history.jsonl"

# stdin の JSON を読み込む
input=$(cat)

ts=$(date '+%F %T %Z')

# 構造化ログ (JSONL): あとから jq で検索・再開できるように全項目を保持
# cwd_tail は cwd の basename。csid 等で「どこで実行したか」を一目で見るための表示用フィールド
jq -c \
  --arg ts "$ts" \
  '{
     timestamp: $ts,
     session_id: .session_id,
     cwd: .cwd,
     cwd_tail: ((.cwd // "") | split("/") | map(select(length > 0)) | last // ""),
     transcript_path: .transcript_path,
     prompt: .prompt
   }' \
  <<<"$input" >>"$JSONL"

exit 0
