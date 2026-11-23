# orchestrate skill

主となる Claude Code（以下「主」）がタスクを受け付けて調査し、実装は herdr workspace 上で起動した別の Claude Code（以下「子」）に任せる。この skill は、その構成を手順と helper スクリプトにまとめたもの。

Claude が従う手順は [SKILL.md](SKILL.md) に書いてある。この README は人が全体像を把握するための説明。

## 目的

- **主の context を汚さない**: 実装の詳細やテストのログは子の側に閉じる。主は長時間動かしても判断の精度が落ちにくい。
- **独立したタスクを並列に進める**: 子ごとに worktree と workspace を分けるので、ファイルがぶつからない。
- **子が調査をやり直す無駄をなくす**: 主が調べた結果を brief ファイルで渡す。子は brief に書いてある調査を繰り返さない。
- **依頼と完了報告を 1 か所に残す**: brief は主と子の契約書になる。主が依頼内容を書き、子が同じファイルの結果欄に完了報告を書く。

## 全体像

```
 ユーザー
   │ /orchestrate <タスク>
   ▼
 主 Claude ──────────── 調査 ──▶ brief を書く (~/.claude/state/briefs/<repo>/<slug>.md)
   │ orchestrate.sh dispatch <slug>
   ├─▶ git worktree add -b task/<slug> ../<repo>-<slug>
   ├─▶ git 管理外の Claude 設定を worktree へコピー
   └─▶ claude-in-herdr.sh ──▶ herdr workspace + 子 Claude を起動
                                 │ 固定の指示文「まず brief を読むこと…」
                                 ▼
                               子 Claude（worktree が cwd）
                                 ├─ brief を読んで実装・テスト・コミット
                                 └─ brief の「## 結果」を記入して合い言葉で報告
 主 Claude ◀── status / collect で回収 ── 完了条件と照合して検証
   │ （ユーザーの確認後）cleanup
   ▼
 worktree を削除し workspace を閉じる、brief は archive/ へ（ブランチは残す）
```

## 使い方

### 委譲する

主にタスクを依頼する。

```
/orchestrate 注文 API に CSV エクスポートを追加して
```

`/orchestrate` を付けなくても、「子に任せて」「並列で進めて」と書けば skill が発動する。

依頼を受けた主は次の順で動く。

1. 関連コードを調査する。
2. `orchestrate.sh brief-path <slug>` で brief のテンプレートを作り、各節を記入する。
3. `orchestrate.sh dispatch <slug>` で子を起動する。
4. agent 名を報告して turn を終える。

### 状況を確認・回収する

主に「状況は？」と聞くと、主は次の順で動く。

1. `status` で全タスクの状態を一覧する。
2. 完了したタスクを `collect` で回収する。完了の判定は、子の状態が `idle` か `done` で、かつ結果欄が記入済みであること。
3. 完了条件と照合して報告する。
4. 不足があれば、`herdr agent prompt <agent> "..."` で子に差し戻す。

### 片付ける

主は確認を求めてから `cleanup` を実行する。worktree を削除し、workspace を閉じ、brief を `archive/` に移す。

## helper スクリプト

`~/.claude/scripts/orchestrate.sh <サブコマンド> [--repo <dir>]`

`--repo` を省略すると cwd のリポジトリを対象にする。主とは別のリポジトリを子に担当させるときに `--repo` を指定する。

| サブコマンド | 動作 |
| --- | --- |
| `brief-path <slug>` | brief のパスを表示する。ファイルがなければテンプレートを作る |
| `dispatch <slug>` | brief の記入を確認し、worktree を作り、子を起動する。メタ情報を `<slug>.json` に保存する |
| `status` | dispatch 中のタスクを `slug / 子の状態 / 結果の記入有無 / worktree` の形で一覧する |
| `collect <slug>` | 結果欄、base からのコミット、変更ファイル、未コミットの変更を表示する |
| `cleanup <slug>` | worktree を削除し、workspace を閉じ、brief とメタ情報を `archive/` に移す。未コミットの変更があれば拒否する。ブランチは残す |

`dispatch` の exit code の意味は次のとおり。

- `0`: 子を起動し、指示を送った。
- `3`: 子は起動したが、承認ダイアログ待ちのため指示を送っていない。出力に再送のコマンドが出る。
- その他: 失敗。

slug に使えるのは `[a-z0-9-]` で、40 文字以内、先頭は英数字。

## brief

置き場所は `~/.claude/state/briefs/<repo>/<slug>.md`。repo の外に置く理由は 2 つある。

- worktree は別の checkout なので、repo 内に置くと子から見えない。
- repo 内に置くと gitignore の設定が要る。

| 節 | 書く人 | 内容 |
| --- | --- | --- |
| `## 目的` | 主 | 何を達成するか。未記入のままだと dispatch が拒否する |
| `## 決定済みの前提と却下した案` | 主 | ユーザーと合意したこと、見送ったことと理由 |
| `## 関連ファイルと再利用できる実装` | 主 | `パス:行` と、そこで何が使えるか |
| `## 触ってよい範囲と完了条件` | 主 | 検証できる完了条件（テストや静的解析など） |
| `## 結果` | 子 | 変更内容、テスト・静的解析の結果、未解決事項、ブランチとコミット |

子に送られるのは固定の短い指示文だけで、依頼内容はすべて brief に書く。

## ファイル構成

| パス | 役割 |
| --- | --- |
| `_claude/skills/orchestrate/SKILL.md` | 主 Claude が従う手順 |
| `_claude/scripts/orchestrate.sh` | 入口。`HERDR_ENV` と python3 の有無を確認する |
| `_claude/scripts/lib/orchestrate.py` | 実体 |
| `_claude/scripts/lib/test_orchestrate.py` | 単体テスト |
| `_claude/scripts/claude-in-herdr.sh` | workspace の作成と子の起動（既存の helper を再利用） |
| `_claude/settings.json` | 子が brief を承認なしで読み書きできるよう、`Edit` / `Read(~/.claude/state/briefs/**)` を許可 |

実行時に作られるファイルは次のとおり。

- `~/.claude/state/briefs/<repo>/<slug>.md`: brief
- `~/.claude/state/briefs/<repo>/<slug>.json`: メタ情報（agent 名、workspace ID、worktree、ブランチ、base コミット、コピーしたファイル）
- `~/.claude/state/briefs/<repo>/archive/`: cleanup 済みの brief とメタ情報

## 子が使う設定

子は worktree を cwd として起動するので、担当リポジトリの `.claude/skills`、`CLAUDE.md`、LEARNING.md を通常どおり使う。

ただし worktree には git で追跡しているファイルしか入らない。そこで dispatch のとき、main worktree にある次のファイルのうち git 管理外のものを worktree へコピーする。

- `.claude/settings.local.json`
- `CLAUDE.local.md`
- `.mcp.json`
- `.claude/skills/`
- `.claude/agents/`

コピーしたファイルはメタ情報に記録する。cleanup のときは、これらを未コミットの変更として扱わない。

## 注意点と制約

- **herdr 専用**: `HERDR_ENV=1` の環境でのみ動く。tmux には対応していない。
- **承認はユーザーが行う**: permission mode の既定が plan なら、子は計画を立てたあと承認待ち（`blocked`）で止まる。
  - 承認はユーザーが該当の workspace で行う。
  - 主が `send-keys` で代わりに承認することは禁止している（auto mode classifier にも拒否される）。
- **未訪問のディレクトリ**: trust ダイアログが出ると、`dispatch` は exit 3 で返る。
- **主の未コミットの変更は子に見えない**: 子は dispatch した時点の HEAD から分岐する。
- **共有リソースの衝突**: Rails の test DB やポートなどは worktree では分離されない。並列で動かすときは、使う DB 名やポートを brief の前提に書く。
- **`git worktree add` を Bash tool で直接実行しない**: `on-worktree-add.sh` hook が別の委譲を起動してしまう。dispatch は git をスクリプト内で実行するので、この hook は発火しない。
- **使い分け**: 数 tool call で終わる調査や修正には向かない。主の中か subagent で済ませる。
- **LEARNING.md の同時書き込み**: 複数の子がほぼ同時に終了すると、SessionEnd の `/learn` が LEARNING.md に同時に書き込み、片方の追記が消える race が起こり得る。この問題は未対策。

## テスト

```sh
python3 ~/.claude/scripts/lib/test_orchestrate.py -v
```

git の操作は一時ディレクトリに作った実リポジトリで確かめ、herdr の呼び出しは `FakeHerdr` で差し替えている。

E2E は次の手順で確認する。

1. herdr 内で使い捨てのリポジトリを作る。
2. `brief-path`、`dispatch`、子の完了、`status`、`collect`、`cleanup` の順に実行する。
3. worktree と workspace が消え、ブランチが残ることを確認する。
