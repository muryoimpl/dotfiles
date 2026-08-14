---
name: claude-in-new-window
description: "別ターミナル (herdr workspace または tmux window) を作成し、指定ディレクトリで claude を起動して、指定した指示文を送信する。以下の場合に発動: (1) ユーザーが /claude-in-new-window <dir> <task> と入力した時、(2) 他 Skill から作業を委譲する目的でチェイン呼び出しされた時、(3) PostToolUse hook (on-worktree-add.sh) が git worktree add を検知して間接的に呼び出す時。herdr / tmux のどちらでもない環境では動作しない。現在の pane はそのまま元のディレクトリに留まる。"
---

# claude-in-new-window

別ターミナルを開き、そこで別 claude セッションを起動し、指定された指示文を自動送信する Skill。worktree に切り替わりたくないが worktree 側で作業させたい、他 Skill から作業を並列委譲したい、といった場面で使う。

実行環境によって委譲先が変わる:

| 環境 | 委譲先 | helper |
| --- | --- | --- |
| `HERDR_ENV=1` | herdr workspace (agent 名付き) | `~/.claude/scripts/claude-in-herdr.sh` |
| `$TMUX` あり | tmux window | `~/.claude/scripts/claude-in-new-window.sh` |
| どちらでもない | 委譲しない (中止) | — |

herdr 版を優先する。herdr は pane 内の agent を認識するため、委譲した claude の
`working` / `blocked` / `done` が sidebar に集約され、承認待ちを見落とさずに済む。

## 前提条件

- herdr セッション内 (`HERDR_ENV=1`) か、tmux セッション内で claude が動いていること
- `<dir>` が実在するディレクトリであること
- `claude` コマンドが `$PATH` にあること
- herdr 版は `herdr` と `jq` が `$PATH` にあること

## 呼び出し方

### 1. ユーザーからの明示呼び出し

```
/claude-in-new-window <dir> <task>
```

- `<dir>`: 新 window の cwd (絶対パス、または現在の cwd からの相対パス)
- `<task>`: 新 window の claude に送信する指示文 (改行やクォート含んで OK)

### 2. 他 Skill / hook からの呼び出し

helper スクリプトを直接呼ぶ:

```sh
~/.claude/scripts/claude-in-herdr.sh <dir> <task>       # herdr
~/.claude/scripts/claude-in-new-window.sh <dir> <task>  # tmux
```

成功時、作成した agent 名 / window 名が stdout に出力される。呼び出し元はそれをユーザーに報告してよい。

## 実行手順

1. **環境を判定して helper を呼ぶ**

   ```sh
   if [ "${HERDR_ENV:-}" = "1" ]; then
     ~/.claude/scripts/claude-in-herdr.sh "<abs-dir>" "<task>"
   elif [ -n "${TMUX:-}" ]; then
     ~/.claude/scripts/claude-in-new-window.sh "<abs-dir>" "<task>"
   else
     : # どちらでもなければ委譲しない
   fi
   ```

   herdr 版 (`claude-in-herdr.sh`) が行うこと:
   - `HERDR_ENV=1` / `herdr` / `jq` / `<dir>` の検証
   - agent 名の決定 (basename を `[a-z][a-z0-9_-]{0,31}` に整形、衝突時は `-2`, `-3`)
   - `herdr workspace create --cwd <dir> --label <name> --no-focus`
   - `herdr agent start <name> --kind claude --pane <id>`
     (shell 初期化との競合で `agent_pane_busy` の間だけリトライ)
   - 承認ダイアログ待ち (`blocked`) なら **task を送らずに exit 3**
   - `herdr agent prompt <name> "<task>"` を送り、画面に現れたことを
     `herdr pane wait-output` で確認 (失敗時は 1 回だけ再送)
   - agent 名を stdout に出力

   tmux 版 (`claude-in-new-window.sh`) が行うこと:
   - tmux 内かの検証、`<dir>` の絶対パス化と存在チェック
   - window 名の決定 (basename ベース、衝突時は `-2`, `-3` と採番)
   - `tmux new-window` → `send-keys 'claude' Enter` → `sleep 3`
   - `<task>` が非空なら `load-buffer` + `paste-buffer` で流し込み `Enter` 送信
   - window 名を stdout に出力

2. **exit code の扱い (herdr 版のみ)**

   | exit | 意味 | 報告 |
   | --- | --- | --- |
   | 0 | 起動と指示送信が完了 | 通常どおり報告 |
   | 3 | 起動したが指示は未送信 (承認ダイアログ待ち等) | ユーザーに承認を促す |
   | その他 | 失敗 | エラー内容を報告 |

3. **結果報告**

   agent 名 / window 名を含めて 1〜2 行で報告する:

   > herdr workspace `<name>` を `<dir>` で作成し、claude 起動と指示送信を完了しました。

4. **turn 終了**

   この Skill を明示呼び出しで使った場合、元 pane の Claude は追加作業を行わず turn を終える。

## 直接 herdr コマンドで書く場合 (helper を使わない fallback)

`herdr` skill が入っていれば、Claude が直接 CLI を叩いてもよい。最小構成:

```sh
created=$(herdr workspace create --cwd "<abs-dir>" --label "<name>" --no-focus)
pane=$(printf '%s' "$created" | jq -r '.result.root_pane.pane_id')
herdr agent start "<name>" --kind claude --pane "$pane"
herdr agent prompt "<name>" "<task>"
```

ただし helper には以下のガードが入っているので、素で書くより helper 経由を推奨する:

- `workspace create` 直後の shell 未初期化 (`agent_pane_busy`) リトライ
- 未訪問ディレクトリの trust ダイアログ検出 (送ると本文が吸われ Enter が「信頼する」を選ぶ)
- 送信取りこぼしの検出と再送

## 直接 tmux コマンドで書く場合 (helper を使わない fallback)

```sh
DIR=$(cd "<入力>" && pwd)
NAME=$(basename "$DIR")
n=2
while tmux list-windows -F '#W' | grep -qx "$NAME"; do
  NAME="$(basename "$DIR")-$n"
  n=$((n+1))
done
tmux new-window -c "$DIR" -n "$NAME"
tmux send-keys -t "$NAME" 'claude' Enter
sleep 3
printf '%s' "<task>" | tmux load-buffer -
tmux paste-buffer -t "$NAME"
tmux send-keys -t "$NAME" Enter
```

`send-keys -l` ではなく `load-buffer` + `paste-buffer` を使う理由: task 文字列に改行 / クォート / バックスラッシュが混ざっても安全に転送できるため。

## 注意点

- **trust ダイアログ (herdr 版)**: 未訪問のディレクトリで claude を起動すると
  "Is this a project you trust?" が出る。helper はこれを `blocked` として検出し、
  task を送らずに exit 3 で返す。ユーザーが承認したあと
  `herdr agent prompt <name> '<task>'` で送り直す。
- **sleep 3 のチューニング (tmux 版)**: claude 起動が遅い環境では 3 秒で足りない場合がある。
  herdr 版は `agent start` が起動検出まで待つのでこの調整は不要。
- **task が空の場合**: helper はターミナルを作って claude を起動するだけで、prompt 送信はスキップする。ユーザーが手動で指示を投入する用途に使える。
- **herdr / tmux 外での実行**: helper が冒頭で検出して中止するので、この Skill 側で個別対処は不要。
- **元 pane の Claude**: この Skill を呼んだ側の Claude は、agent 名 / window 名を報告して turn を終える。委譲した作業を追いかけて元 pane 側でも進めない。

## 関連

- 自動発動 hook: `~/.claude/scripts/on-worktree-add.sh` (PostToolUse Bash chain) が `git worktree add` の成功を検知し、`HERDR_ENV` / `$TMUX` を見て helper を振り分ける。
- 委譲先の可視化 (herdr): sidebar の Agent panel が `blocked` / `done` を集約する。
  `prefix+ctrl+n` / `prefix+alt+1..9` で agent 間を移動、`prefix+o` で通知対象へジャンプできる。
- 委譲先の可視化 (tmux): `~/.config/tmux/scripts/claude-window-flag.sh` により、新 window で claude が起動すると status bar 上で紫背景に変わる。
