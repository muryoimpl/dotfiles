---
name: orchestrate
description: "主 Claude が調査結果を brief にまとめ、タスクごとの git worktree と herdr workspace で子 Claude を起動して委譲し、後で結果を回収・検証する。以下の場合に発動: (1) ユーザーが /orchestrate <task> と入力した時、(2) 「子に任せて」「並列で進めて」「別 workspace でやって」など委譲を依頼された時、(3) 「状況は？」「子の結果を確認して」など委譲済みタスクの回収を依頼された時。HERDR_ENV=1 の環境でのみ動作する。"
---

# orchestrate

主 Claude はタスクの受付・調査・検証を担い、実装は子 Claude に任せる。
主の調査結果は brief ファイルで子に渡し、子が同じ調査をやり直す無駄をなくす。
brief は依頼内容と完了報告を兼ねる、主と子の契約書になる。

helper: `~/.claude/scripts/orchestrate.sh`（全サブコマンドで `--repo <dir>` を指定できる。省略時は cwd のリポジトリ）

## 使う場面

- 実装を伴い、他の作業から独立していて、時間がかかるタスク
- 数 tool call で終わる調査や修正には使わない。主の中か subagent で済ませる
- 前提: `HERDR_ENV=1`。それ以外の環境では委譲せず、その旨を伝える

## 委譲の手順

1. **slug を決める**: `[a-z0-9-]`、40 文字以内。例: `order-csv-export`
   - ブランチ `task/<slug>` と worktree `<repo>-<slug>`（main worktree と同じ階層）が作られる
2. **調査する**: 子がやり直さずに済むよう、関連ファイル、再利用できる実装、テストの手本を特定する。広い探索には Explore subagent を使ってよい
3. **brief を書く**:

   ```sh
   ~/.claude/scripts/orchestrate.sh brief-path <slug>
   ```

   - 出力されたパスのテンプレートを Read し、Edit / Write で各節を埋める
   - `## 目的`: 何を達成するか
   - `## 決定済みの前提と却下した案`: ユーザーと合意したこと、見送ったことと理由。書かなければ子には伝わらない
   - `## 関連ファイルと再利用できる実装`: `パス:行` と、そこで何が使えるか
   - `## 触ってよい範囲と完了条件`: テスト、静的解析など検証できる条件にする
   - `## 結果` は子が記入する欄なので、主は空のまま残す
4. **dispatch する**:

   ```sh
   ~/.claude/scripts/orchestrate.sh dispatch <slug>
   ```

   - exit 0: 子が起動し、指示を送信済み
   - exit 3: 子は承認ダイアログ待ち。出力に再送のコマンドが出るので、ユーザーに承認を促して伝える
   - その他: 失敗。エラー内容を報告する
5. **報告して turn を終える**: slug、agent 名、worktree を 1〜2 行で報告する
   - 委譲した作業を主で追いかけない
   - 複数のタスクを並列に進めるなら、手順 1〜4 を続けて繰り返してから報告する

子には次の固定文だけが送られる。依頼内容はすべて brief に書く。

> まず `<brief>` を読むこと。brief に書いてある調査はやり直さず、足りない点だけ調べる。完了したら brief の `## 結果` 節に（中略）記入してから、合い言葉で報告する。

## 回収と検証の手順

ユーザーから状況を聞かれた時や、herdr で子の作業が止まった時に行う。

完了の判定は「子の状態が `idle` または `done`」かつ「結果が記入済み」とする。子は turn を終えると `idle` に戻ることが多く、`done` だけを待つと完了を見落とすため。`idle` でも結果が未記入なら、子は途中で止まっている。`herdr agent read <agent>` で画面を確認する。

1. 一覧を見る:

   ```sh
   ~/.claude/scripts/orchestrate.sh status
   ```

   各行は `slug / 子の状態 (working, blocked, done, idle, 不在) / 結果の記入有無 / worktree`
2. 完了したタスク（`idle` / `done` かつ「結果: 記入済み」）を回収する:

   ```sh
   ~/.claude/scripts/orchestrate.sh collect <slug>
   ```

   結果欄、base からのコミット、変更ファイル、未コミットの変更が出る
3. **検証する**: brief の完了条件と照合する
   - 結果欄の主張を鵜呑みにしない。必要なら worktree で diff を読み、テストを実行して確かめる
4. 不足があれば差し戻す:

   ```sh
   herdr agent prompt <agent> "<不足点と直してほしいこと>"
   ```

5. 問題なければユーザーに報告する。PR 作成やマージは、ユーザーの指示があるときだけ行う
6. **片付け**: 必ずユーザーに確認してから実行する

   ```sh
   ~/.claude/scripts/orchestrate.sh cleanup <slug>
   ```

   - worktree を削除し、herdr workspace を閉じ、brief を `archive/` に移す
   - ブランチは残す
   - 未コミットの変更があると拒否する

## 注意点

- 子は worktree を cwd として起動する。担当リポジトリの `.claude/skills`、`CLAUDE.md`、LEARNING.md を通常どおり使う
  - git 管理外の `.claude/settings.local.json`、`CLAUDE.local.md`、`.mcp.json`、`.claude/skills`、`.claude/agents` は dispatch 時に worktree へコピーされる
- 子はユーザー設定の permission mode で起動する。plan mode が既定なら、子は brief を読んで計画を立てた後、承認待ち（`blocked`）で止まる
  - 計画の承認や permission の許可は、ユーザーが herdr の該当 workspace で行う
  - 主が `herdr agent send-keys` で代わりに承認してはいけない
  - `status` で `blocked` を見つけたら、どの workspace の承認待ちかをユーザーに伝える
- 主で未コミットの変更は子には見えない。子は dispatch 時点の HEAD から分岐する
- Rails などで test DB やポートを共有するタスクを並列に動かすと衝突する。brief の前提に、使う DB 名やポートを書いておく
- `git worktree add` を Bash tool で直接実行しないこと。`on-worktree-add.sh` hook が別の委譲を起動してしまう。worktree の作成は必ず dispatch に任せる
