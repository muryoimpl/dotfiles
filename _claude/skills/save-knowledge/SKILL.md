---
name: save-knowledge
description: 現在のセッションでの Q&A を、別リポジトリで作業中でも muryoimpl/knowledge-docs リポジトリにエントリとして保存し INDEX を再生成する。「この内容を保存」「ナレッジに残して」「/save-knowledge」などで起動。
---

# save-knowledge

現在の Claude Code セッションでのユーザーの質問と回答を、知識ベースリポジトリ
`muryoimpl/knowledge-docs` に 1 件の markdown エントリとして保存し、INDEX を再生成する。

**どのリポジトリで作業中でも動作する。** 作業中のリポジトリの git 履歴は一切変更せず、
保存・コミットは knowledge-docs リポジトリに対してのみ行う。

## 前提: 保存先リポジトリのパス解決

最初に knowledge-docs のパスを解決し、以降 `$REPO` として扱う。次を Bash で実行する。

```bash
REPO="${KNOWLEDGE_DOCS_DIR:-}"
[ -z "$REPO" ] && REPO="$(ghq list --full-path muryoimpl/knowledge-docs 2>/dev/null | head -1)"
[ -z "$REPO" ] && REPO="$(ghq root 2>/dev/null)/github.com/muryoimpl/knowledge-docs"
echo "$REPO"
```

`$REPO` が存在しない場合はユーザーに場所を確認する。

## 重要な原則

- ファイル作成・INDEX 生成・git 操作は **すべて絶対パス / `git -C "$REPO"`** で knowledge-docs に対して行う。
- 作業中リポジトリ（カレントディレクトリ）で `git add` / `git commit` を **絶対に実行しない**。

## 手順

1. **保存対象の抽出**: 直前のやり取りから、後で見返す価値のある「質問」と「回答の要点」をまとめる。
   長い回答は要点を整理して簡潔にする（会話ログの丸写しにしない）。引数 `$ARGUMENTS` は
   カテゴリ名やタイトルのヒント（任意）。

2. **元リポジトリ情報の取得**（source 用。カレントが knowledge-docs 自身なら省略可）:

   ```bash
   origin="$(git config --get remote.origin.url 2>/dev/null)"
   branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
   # origin から owner/repo を抽出し "owner/repo@branch" 形式にする
   ```

3. **メタデータの決定**:
   - `title`: 内容を表す簡潔なタイトル。
   - `category`: `ls "$REPO/docs/"` で既存カテゴリを確認し、合うものを優先。
     該当が無ければ新規カテゴリ（新規ディレクトリ）の作成可否をユーザーに確認する。
   - `tags`: 検索用タグを数個（英小文字）。
   - `slug`: 英小文字ケバブケース（例: `active-record-n1`）。
   - `date`: 本日の日付（`YYYY-MM-DD`）。
   - `source`: 手順 2 の `owner/repo@branch`（knowledge-docs 自身での実行時は付けない）。

4. **ファイル作成**: `$REPO/templates/entry.md` を雛形として
   `$REPO/docs/<category>/<YYYY-MM-DD>-<slug>.md` を作成し、frontmatter と本文（質問・回答・参考）を埋める。
   別リポジトリ由来のときは frontmatter に `source` を含める。

5. **INDEX 再生成**: `ruby "$REPO/scripts/build_index.rb"` を実行して `INDEX.md` を更新する。

6. **コミット**: knowledge-docs 側へ自動でコミットする（作業中リポジトリには触れない）。

   ```bash
   git -C "$REPO" add docs INDEX.md
   git -C "$REPO" commit -m "エントリ追加: <title>"
   ```

7. **push は確認**: コミット後、origin へ push するかどうかをユーザーに確認する。
   了承された場合のみ `git -C "$REPO" push` を実行する。

8. **報告**: 保存したファイルパス、コミットハッシュ、INDEX 再生成結果（件数・警告）、push の有無を報告する。

## 運用ルール

- 既存カテゴリへの追記は確認せず即実行してよい。
- 新規カテゴリ（新規ディレクトリ）を作る場合のみ、事前にユーザーへ確認する。
- push はユーザーが了承したときのみ実行する。
