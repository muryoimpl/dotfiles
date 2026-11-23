#!/usr/bin/env python3
"""主 Claude が調査結果を brief に書き、herdr workspace 上の子 Claude へ委譲する。

brief は repo の外 (~/.claude/state/briefs/<repo>/<slug>.md) に置く。
worktree は別 checkout なので repo 内に置くと子から見えず、gitignore も要るため。
"""

import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from learning import project_root

BRIEFS_DIR = Path.home() / ".claude" / "state" / "briefs"
HELPER = Path.home() / ".claude" / "scripts" / "claude-in-herdr.sh"

# worktree には git 管理のファイルしか入らないが、子は担当 repo の
# ローカル設定や skill を使って作業するため、管理外のものだけ持ち込む。
LOCAL_CLAUDE_PATHS = [
    ".claude/settings.local.json",
    "CLAUDE.local.md",
    ".mcp.json",
    ".claude/skills",
    ".claude/agents",
]

_SLUG = re.compile(r"[a-z0-9][a-z0-9-]{0,39}")
_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)

TEMPLATE = """# {slug}

<!-- 主が記入し、子は読んでから作業する。ここに書いた調査は子がやり直さない。 -->

## 目的

## 決定済みの前提と却下した案

## 関連ファイルと再利用できる実装

<!-- パス:行 と、そこで何が使えるか -->

## 触ってよい範囲と完了条件

## 結果

<!-- 子が完了時に記入する: 変更内容 / テスト・静的解析の結果 / 未解決事項 / ブランチとコミット -->
"""

CHILD_PROMPT = (
    "まず {brief} を読むこと。brief に書いてある調査はやり直さず、足りない点だけ調べる。"
    "完了したら brief の `## 結果` 節に変更内容、テスト・静的解析の結果、未解決事項、"
    "ブランチとコミットを記入してから、合い言葉で報告する。"
)


def validate_slug(slug):
    if not _SLUG.fullmatch(slug or ""):
        raise ValueError(f"slug は [a-z0-9-] で 40 文字以内、先頭は英数字にしてください: {slug!r}")
    return slug


def render_template(slug):
    return TEMPLATE.format(slug=slug)


def extract_section(text, heading):
    lines = text.splitlines()
    body = []
    inside = False
    for line in lines:
        if line.startswith("## "):
            if inside:
                break
            inside = line[3:].strip() == heading
            continue
        if inside:
            body.append(line)
    return _COMMENT.sub("", "\n".join(body)).strip()


def is_filled(text):
    return bool(extract_section(text, "目的"))


def has_result(text):
    return bool(extract_section(text, "結果"))


def resolve_root(directory):
    root = project_root(os.path.abspath(directory))
    if not root:
        raise ValueError(f"git リポジトリではありません: {directory}")
    return root


def _task_dir(root, base):
    return Path(base) / os.path.basename(root)


def _brief(root, slug, base):
    return _task_dir(root, base) / f"{validate_slug(slug)}.md"


def _meta(root, slug, base):
    return _task_dir(root, base) / f"{validate_slug(slug)}.json"


def ensure_brief(root, slug, base=BRIEFS_DIR):
    path = _brief(root, slug, base)
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(render_template(slug))
    return str(path)


def worktree_path(root, slug):
    return os.path.join(os.path.dirname(root), f"{os.path.basename(root)}-{validate_slug(slug)}")


def _git(cwd, *args):
    proc = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True)
    if proc.returncode != 0:
        raise ValueError(proc.stderr.strip() or f"git {' '.join(args)} が失敗しました")
    return proc.stdout


def _copy_local_claude_files(root, worktree):
    out = _git(root, "ls-files", "--others", "-z", "--", *LOCAL_CLAUDE_PATHS)
    copied = []
    for rel in filter(None, out.split("\0")):
        dst = Path(worktree) / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(Path(root) / rel, dst)
        copied.append(rel)
    return copied


def dispatch(root, slug, herdr, base=BRIEFS_DIR):
    brief = _brief(root, slug, base)
    meta_path = _meta(root, slug, base)
    if not brief.exists():
        raise ValueError(f"brief がありません。先に brief-path で作成してください: {brief}")
    if not is_filled(brief.read_text()):
        raise ValueError(f"brief の「目的」が未記入です: {brief}")
    if meta_path.exists():
        raise ValueError(f"{slug} は dispatch 済みです。status で状態を確認してください")

    worktree = worktree_path(root, slug)
    branch = f"task/{slug}"
    base_commit = _git(root, "rev-parse", "HEAD").strip()
    _git(root, "worktree", "add", "-q", "-b", branch, worktree)
    copied = _copy_local_claude_files(root, worktree)

    rc, agent = herdr.launch(worktree, CHILD_PROMPT.format(brief=brief))
    info = herdr.get(agent) if agent else None
    meta = {
        "slug": slug,
        "agent": agent,
        "workspace_id": (info or {}).get("workspace_id"),
        "worktree": worktree,
        "branch": branch,
        "base": base_commit,
        "copied": copied,
        "created_at": datetime.datetime.now().isoformat(timespec="seconds"),
    }
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n")

    lines = [
        f"brief: {brief}",
        f"worktree: {worktree}",
        f"branch: {branch}",
        f"agent: {agent or '(起動失敗)'}",
    ]
    if copied:
        lines.append("copied: " + ", ".join(copied))
    if rc == 3:
        lines.append("子は承認ダイアログ待ちのため指示を未送信です。承認後に次を実行してください:")
        lines.append(f"  herdr agent prompt {agent} {json.dumps(CHILD_PROMPT.format(brief=brief), ensure_ascii=False)}")
    return rc, lines


def _load_meta(path):
    return json.loads(Path(path).read_text())


def status(root, herdr, base=BRIEFS_DIR):
    task_dir = _task_dir(root, base)
    metas = sorted(task_dir.glob("*.json")) if task_dir.is_dir() else []
    if not metas:
        return f"{os.path.basename(root)} に dispatch 中のタスクはありません"
    rows = []
    for meta_path in metas:
        meta = _load_meta(meta_path)
        info = herdr.get(meta["agent"]) if meta.get("agent") else None
        state = info.get("agent_status", "unknown") if info else "不在"
        brief = meta_path.with_suffix(".md")
        result = "記入済み" if brief.exists() and has_result(brief.read_text()) else "未記入"
        rows.append(f"{meta['slug']}\t{state}\t結果: {result}\t{meta['worktree']}")
    return "\n".join(rows)


def collect(root, slug, base=BRIEFS_DIR):
    meta_path = _meta(root, slug, base)
    if not meta_path.exists():
        raise ValueError(f"{slug} は dispatch されていません")
    meta = _load_meta(meta_path)
    brief = _brief(root, slug, base)
    result = extract_section(brief.read_text(), "結果") if brief.exists() else ""
    parts = [f"# {slug} ({meta['branch']})", "", "## 結果", result or "(未記入)"]
    worktree = meta["worktree"]
    if os.path.isdir(worktree):
        parts += [
            "", "## コミット", _git(worktree, "log", "--oneline", f"{meta['base']}..HEAD").strip() or "(なし)",
            "", "## 変更ファイル (base との差分、未コミット含む)",
            _git(worktree, "diff", "--stat", meta["base"]).strip() or "(なし)",
            "", "## 未コミット", _git(worktree, "status", "--short").strip() or "(なし)",
        ]
    else:
        parts += ["", f"worktree がありません: {worktree}"]
    return "\n".join(parts)


def cleanup(root, slug, herdr, base=BRIEFS_DIR):
    meta_path = _meta(root, slug, base)
    if not meta_path.exists():
        raise ValueError(f"{slug} は dispatch されていません")
    meta = _load_meta(meta_path)
    worktree = meta["worktree"]
    copied = set(meta.get("copied", []))
    messages = []

    if os.path.isdir(worktree):
        dirty = [
            line for line in _git(worktree, "status", "--porcelain", "-uall").splitlines()
            if line[3:] not in copied
        ]
        if dirty:
            raise ValueError("worktree に未コミットの変更があるため削除しません:\n" + "\n".join(dirty))
        for rel in copied:
            Path(worktree, rel).unlink(missing_ok=True)
        _git(root, "worktree", "remove", worktree)
        messages.append(f"worktree を削除しました: {worktree} (ブランチ {meta['branch']} は残しています)")

    if meta.get("workspace_id"):
        if herdr.close_workspace(meta["workspace_id"]):
            messages.append(f"herdr workspace {meta['workspace_id']} を閉じました")
        else:
            messages.append(f"herdr workspace {meta['workspace_id']} を閉じられませんでした")

    archive = _task_dir(root, base) / "archive"
    archive.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    for src in (_brief(root, slug, base), meta_path):
        if src.exists():
            shutil.move(str(src), str(archive / f"{slug}-{stamp}{src.suffix}"))
    messages.append(f"brief を {archive} に移しました")
    return messages


class Herdr:
    def launch(self, directory, prompt):
        proc = subprocess.run([str(HELPER), directory, prompt], stdout=subprocess.PIPE, text=True)
        lines = proc.stdout.splitlines()
        return proc.returncode, (lines[0].strip() if lines else None)

    def get(self, name):
        proc = subprocess.run(["herdr", "agent", "get", name], capture_output=True, text=True)
        if proc.returncode != 0:
            return None
        try:
            return json.loads(proc.stdout)["result"]["agent"]
        except (ValueError, KeyError, TypeError):
            return None

    def close_workspace(self, workspace_id):
        proc = subprocess.run(["herdr", "workspace", "close", workspace_id], capture_output=True, text=True)
        return proc.returncode == 0


def _parser():
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--repo", default=os.getcwd(), help="対象リポジトリ (省略時は cwd)")
    parser = argparse.ArgumentParser(prog="orchestrate.sh")
    sub = parser.add_subparsers(dest="cmd", required=True)
    for name in ("brief-path", "dispatch", "collect", "cleanup"):
        sub.add_parser(name, parents=[common]).add_argument("slug")
    sub.add_parser("status", parents=[common])
    return parser


def main(argv=None):
    args = _parser().parse_args(argv)
    herdr = Herdr()
    try:
        root = resolve_root(args.repo)
        if args.cmd == "brief-path":
            print(ensure_brief(root, args.slug))
            return 0
        if args.cmd == "dispatch":
            rc, lines = dispatch(root, args.slug, herdr)
            print("\n".join(lines))
            return rc
        if args.cmd == "status":
            print(status(root, herdr))
            return 0
        if args.cmd == "collect":
            print(collect(root, args.slug))
            return 0
        if args.cmd == "cleanup":
            print("\n".join(cleanup(root, args.slug, herdr)))
            return 0
    except ValueError as e:
        print(e, file=sys.stderr)
        return 1
    return 1


if __name__ == "__main__":
    sys.exit(main())
