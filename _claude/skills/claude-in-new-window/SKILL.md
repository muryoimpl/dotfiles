---
name: claude-in-new-window
description: "tmux の新しい window を作成し、指定ディレクトリで claude を起動して、指定した指示文を送信する。以下の場合に発動: (1) ユーザーが /claude-in-new-window <dir> <task> と入力した時、(2) 他 Skill から新 window で claude に作業を委譲する目的でチェイン呼び出しされた時、(3) PostToolUse hook (on-worktree-add.sh) が git worktree add を検知して間接的に呼び出す時。tmux 外では動作しない。現在の pane はそのまま元のディレクトリに留まる。"
---

# claude-in-new-window

tmux の新しい window を開き、そこで別 claude セッションを起動し、指定された指示文を自動送信する Skill。worktree に切り替わりたくないが worktree 側で作業させたい、他 Skill から作業を並列委譲したい、といった場面で使う。

## 前提条件

- tmux セッション内で claude が動いていること (tmux 外では即中止)
- `<dir>` が実在するディレクトリであること
- `claude` コマンドが `$PATH` にあること

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
~/.claude/scripts/claude-in-new-window.sh <dir> <task>
```

成功時、作成した window 名が stdout に出力される。呼び出し元はそれをユーザーに報告してよい。

## 実行手順

1. **helper スクリプトを呼ぶ**

   基本はこれ 1 つで完結する:

   ```sh
   ~/.claude/scripts/claude-in-new-window.sh "<abs-dir>" "<task>"
   ```

   スクリプトが以下を全て行う:
   - tmux 内かの検証
   - `<dir>` の絶対パス化と存在チェック
   - window 名の決定 (basename ベース、衝突時は `-2`, `-3` と採番)
   - `tmux new-window -c <dir> -n <name>`
   - `tmux send-keys 'claude' Enter`
   - `sleep 3` で claude 起動待ち
   - `<task>` が非空なら `tmux load-buffer` + `paste-buffer` で流し込み `Enter` 送信
   - 作成した window 名を stdout に出力

2. **結果報告**

   window 名を含めて 1〜2 行で報告する:

   > tmux window `<name>` を `<dir>` で作成し、claude 起動と指示送信を完了しました。

3. **turn 終了**

   この Skill を明示呼び出しで使った場合、元 pane の Claude は追加作業を行わず turn を終える。

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

- **sleep 3 のチューニング**: claude 起動が遅い環境では 3 秒で足りない場合がある。その場合は helper スクリプトの `sleep` を延ばすか、`tmux capture-pane` で起動完了を検出する方式に差し替える。
- **task が空の場合**: helper は window を作って claude を起動するだけで、prompt 送信はスキップする。ユーザーが手動で指示を投入する用途に使える。
- **tmux 外での実行**: helper が冒頭で検出して中止するので、この Skill 側で個別対処は不要。
- **元 pane の Claude**: この Skill を呼んだ側の Claude は、window 名を報告して turn を終える。委譲した作業を追いかけて元 pane 側でも進めない。

## 関連

- 自動発動 hook: `~/.claude/scripts/on-worktree-add.sh` (PostToolUse Bash chain) が `git worktree add` の成功を検知して helper を呼ぶ。
- window ハイライト: `~/.config/tmux/scripts/claude-window-flag.sh` により、新 window で claude が起動すると status bar 上で紫背景に変わる。
