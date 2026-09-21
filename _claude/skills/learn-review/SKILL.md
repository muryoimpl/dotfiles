---
name: learn-review
description: プロジェクトの LEARNING.md の全項目を見直し、古い項目の削除・重複の統合・パターンの原則化を行い、CLAUDE.md にそのまま貼れる形の提案を SUGGESTION.md に書き出す。ユーザーが /learn-review と入力した時、または週が変わって最初の SessionStart hook から `claude -p` 経由で自動実行された時に動く。
argument-hint: "[LEARNING.md のパス]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(~/.claude/scripts/learning.sh:*)
---

# learn-review

LEARNING.md は毎セッション読み込まれるので、放っておくと古い項目や重複で膨らみ、
本当に効く原則が埋もれる。週に一度、全項目を棚卸しして LEARNING.md を軽く保ち、
繰り返し現れるパターンは原則として SUGGESTION.md に書き出す。

## 手順

### 1. 対象ファイルを決める

次の順で決め、以降 `$LEARNING` として扱う。同じディレクトリの `SUGGESTION.md` を `$SUGGESTION` とする。

1. 引数 `$ARGUMENTS` があればそのパス
2. SessionStart で注入された `[LEARNING.md 読み込み済み] <path>` の path
3. どちらも無ければ `~/.claude/scripts/learning.sh path` の出力

`$LEARNING` が無ければ「LEARNING.md がありません: <path>」と報告して終了する。

### 2. 材料を読む

- `$LEARNING`
- プロジェクトの CLAUDE.md（ルートと `.claude/CLAUDE.md`）
- `~/.claude/CLAUDE.md` と `~/.claude/rules/*.md`（既に原則化されているものを提案しないため）
- 前回の `$SUGGESTION`（あれば。持ち越し判定に使う）

### 3. 全項目をレビューする

各項目に対して次の順で判定する。

**削除**（いずれかに該当）

- 日付から 90 日を超えていて、その後に再確認された形跡が無い
- 既にプロジェクトの CLAUDE.md、`~/.claude/CLAUDE.md`、rules に取り込まれている
- コードや設定を確認すると現状と矛盾している（確認は Grep / Read を数回まで。深追いしない）

**統合**

- 同義、または一方が他方を含む項目は 1 つにまとめる。日付は新しい方にする
- まとめた結果が 2 行を超えるなら、原則として SUGGESTION.md へ送り、LEARNING.md には短い形で残す

**パターン抽出**

- 2 件以上の項目が同じ原則を指している
- 1 件でも、再発したときのコストが高い（データ破壊、本番影響、長時間の手戻り）

該当するものは「原則」として文章化する。原則は「何をするか／しないか」と「なぜ」が 1〜3 行で分かる形にする。

### 4. LEARNING.md を書き戻す

- セクション見出し（失敗と対策 / 業務知識 / プロジェクト固有の作法 / その他）と `- YYYY-MM-DD: ...` の形式を維持する
- `<!-- last-reviewed: YYYY-MM-DD -->` を今日の日付に更新する
- 削除・統合した項目は LEARNING.md からは消し、SUGGESTION.md の「レビューで削除・統合した項目」に記録する

### 5. SUGGESTION.md を生成する

下のフォーマットで `$SUGGESTION` を **上書き** する。

- 「CLAUDE.md への提案」は、このプロジェクトの CLAUDE.md にそのまま貼れる文体で書く（ですます調、日本語と半角英数字の間に半角スペース、箇条書き）
- 各提案には根拠となった LEARNING.md の項目（日付と要旨）を添える
- 前回の SUGGESTION.md にあった提案のうち、まだ CLAUDE.md に取り込まれていないものは「前回からの持ち越し」に残す。取り込まれたものは載せない
- 提案が無ければ「CLAUDE.md への提案」に「今回はありません」と書く

```markdown
# SUGGESTION.md — YYYY-MM-DD レビュー

LEARNING.md の全項目レビュー結果。このプロジェクトの CLAUDE.md にそのまま貼れる形で原則を提案する。

## CLAUDE.md への提案

### 1. <原則の見出し>

- <CLAUDE.md にそのまま貼れる 1〜3 行>
- 根拠: LEARNING.md の項目（YYYY-MM-DD <要旨>、YYYY-MM-DD <要旨>）

## 前回からの持ち越し

- <前回の提案で未反映のもの。無ければ「なし」>

## レビューで削除・統合した項目

- 削除: <項目>（理由: 90 日超 / CLAUDE.md に取り込み済み / 現状と矛盾）
- 統合: <A> + <B> → <C>
```

### 6. 報告する

「LEARNING.md レビュー: 削除 n 件、統合 m 件、提案 k 件 → SUGGESTION.md」の 1 行に続けて、提案の見出しだけを列挙する。

## 運用ルール

- CLAUDE.md 自体は編集しない。提案を採用するかはユーザーが SUGGESTION.md を見て決める
- LEARNING.md の項目を「書き直す」ときも事実は変えない。要約と統合だけ行う
- 判断に迷う項目は削除せず残す。消すより残す方が安全
