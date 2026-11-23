#!/bin/sh
# 主 Claude が brief を書き、herdr workspace 上の子 Claude へ委譲する。
#
# サブコマンド ([--repo <dir>] は全サブコマンド共通、省略時は cwd):
#   brief-path <slug>  brief のパスを表示する (無ければテンプレートを作る)
#   dispatch <slug>    task/<slug> の worktree を作り、子 claude を起動して brief を読ませる
#   status             dispatch 中のタスクと子の状態を一覧する
#   collect <slug>     brief の結果欄とコミット・差分を表示する
#   cleanup <slug>     worktree を削除し、workspace を閉じ、brief を archive に移す
#
# dispatch の exit 3 は「子は起動したが承認待ちで指示未送信」。
# 実体は lib/orchestrate.py。

[ "${HERDR_ENV:-}" = "1" ] || { echo "herdr セッション外です" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 が見つかりません" >&2; exit 1; }

exec python3 "$(dirname "$0")/lib/orchestrate.py" "$@"
