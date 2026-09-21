#!/usr/bin/env python3
"""プロジェクトごとの LEARNING.md を読み込み (SessionStart)、学びを抽出する (SessionEnd) hook の実体。

Claude Code には「セッション終了時に LLM を動かす」hook が無い。SessionEnd は shell command しか
呼べないので、ここから `claude -p --resume <session_id> "/learn <path>"` を背景で起動し、
終わったセッションを全文脈つきで再開して LEARNING.md に学びを書かせる。

SessionStart では LEARNING.md の全文を additionalContext で注入し、systemMessage で読み込み済みを
ユーザーに見せる。週が変わって最初の startup では `claude -p "/learn-review <path>"` を背景で起動し、
古い項目の削除・重複排除・原則化 (SUGGESTION.md) を行わせる。

LEARNING.md の置き場所は main worktree のルート (`git rev-parse --git-common-dir` の親)。
linked worktree で作業していても学びは 1 か所に集める。global gitignore 済みで git には入らない。

背景で起動した claude 自身の hook が再びこれを呼ぶので、子には CLAUDE_LEARN_AUTO=1 を渡して再帰を止める。
herdr の環境変数も落とし、子の hook が pane の状態や tab のラベルを触らないようにする。
呼び出しは ~/.claude/scripts/learning.sh。
"""

import datetime
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / "state" / "learning"

AUTO_ENV = "CLAUDE_LEARN_AUTO"
DRY_RUN_ENV = "CLAUDE_LEARN_DRY_RUN"
MODEL_ENV = "CLAUDE_LEARN_MODEL"
HERDR_ENV_KEYS = ("HERDR_ENV", "HERDR_PANE_ID", "HERDR_SOCKET_PATH")

# `other` は headless 終了や SIGTERM を含むので対象外。対話セッションの終わり方だけ拾う
EXTRACT_REASONS = {"prompt_input_exit", "clear", "logout", "resume"}
ALLOWED_TOOLS = "Read,Glob,Grep,Edit,Write"
EXTRACT_DELAY_SEC = 3
LOG_KEEP_DAYS = 30

_LAST_REVIEWED = re.compile(r"<!--\s*last-reviewed:\s*(\d{4}-\d{2}-\d{2})\s*-->")
_COMMAND_NAME = re.compile(r"<command-name>\s*(/\S+)\s*</command-name>")


def project_root(cwd):
    if not cwd or not os.path.isdir(cwd):
        return None
    try:
        proc = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--git-common-dir"],
            capture_output=True, text=True, timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    common = proc.stdout.strip()
    if proc.returncode != 0 or not common:
        return None
    common = os.path.abspath(os.path.join(cwd, common))
    return os.path.dirname(common)


def learning_path(root):
    return os.path.join(root, "LEARNING.md")


def state_key(root):
    return root.replace("/", "-")


def parse_learning(text):
    items = sum(1 for line in text.splitlines() if line.startswith("- "))
    last_reviewed = None
    m = _LAST_REVIEWED.search(text)
    if m:
        try:
            last_reviewed = datetime.date.fromisoformat(m.group(1))
        except ValueError:
            last_reviewed = None
    return {"items": items, "last_reviewed": last_reviewed}


def iso_week(day):
    year, week, _ = day.isocalendar()
    return f"{year}-W{week:02d}"


def review_due(last_reviewed, stamp_week, today):
    week = iso_week(today)
    if stamp_week == week:
        return False
    if last_reviewed and iso_week(last_reviewed) == week:
        return False
    return True


def _user_texts(transcript_path):
    try:
        with open(transcript_path, encoding="utf-8") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(rec, dict) or rec.get("type") != "user" or rec.get("isMeta"):
                    continue
                content = (rec.get("message") or {}).get("content")
                if isinstance(content, str):
                    yield content
                elif isinstance(content, list):
                    texts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"]
                    if texts:
                        yield "\n".join(texts)
    except OSError:
        return


def _is_command(text):
    return "<command-name>" in text or "<local-command-stdout>" in text


def count_user_prompts(transcript_path):
    return sum(1 for text in _user_texts(transcript_path) if not _is_command(text))


def learn_already_run(transcript_path):
    # `/learn` の後に来るのは `/exit` などの終了コマンドだけなので、それを飛ばして最後の発話を見る
    for text in reversed(list(_user_texts(transcript_path))):
        m = _COMMAND_NAME.search(text)
        name = m.group(1) if m else text.strip().split()[0] if text.strip() else ""
        if name in ("/exit", "/quit", "/clear", "/logout", "/resume"):
            continue
        return name == "/learn"
    return False


def should_extract(hook_input, env):
    if env.get(AUTO_ENV):
        return False, f"{AUTO_ENV} が設定されている (自動実行の子セッション)"
    reason = hook_input.get("reason")
    if reason not in EXTRACT_REASONS:
        return False, f"reason={reason} は対象外"
    if not hook_input.get("session_id"):
        return False, "session_id が無い"
    cwd = hook_input.get("cwd")
    if not cwd or not os.path.isdir(cwd):
        return False, "cwd が存在しない"
    if project_root(cwd) is None:
        return False, "git 管理外"
    transcript = hook_input.get("transcript_path")
    if not transcript or not os.path.isfile(transcript):
        return False, "transcript が無い"
    if count_user_prompts(transcript) < 1:
        return False, "ユーザー発話が無い"
    if learn_already_run(transcript):
        return False, "/learn は実行済み"
    return True, "ok"


def _claude_command(prompt, env, resume=None):
    cmd = ["claude", "-p"]
    if resume:
        cmd += ["--resume", resume]
    cmd += [prompt, "--permission-mode", "acceptEdits", "--allowedTools", ALLOWED_TOOLS]
    model = env.get(MODEL_ENV)
    if model:
        cmd += ["--model", model]
    return cmd


def learn_command(session_id, path, env):
    return _claude_command(f"/learn {path}", env, resume=session_id)


def review_command(path, env):
    return _claude_command(f"/learn-review {path}", env)


def child_env(env):
    child = {k: v for k, v in env.items() if k not in HERDR_ENV_KEYS}
    child[AUTO_ENV] = "1"
    return child


def with_delay(cmd, seconds):
    return ["sh", "-c", f'sleep {int(seconds)}; exec "$@"', "sh", *cmd]


def spawn(cmd, cwd, log_path, env):
    log_path = Path(log_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%F %T")
    if env.get(DRY_RUN_ENV):
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"[{stamp}] DRY RUN cwd={cwd}: {shlex.join(cmd)}\n")
        return False
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(f"[{stamp}] cwd={cwd}: {shlex.join(cmd)}\n")
        f.flush()
        subprocess.Popen(
            cmd, cwd=cwd, env=child_env(env),
            stdin=subprocess.DEVNULL, stdout=f, stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    return True


def _log_path(state_dir, kind, key):
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    return Path(state_dir) / "logs" / f"{ts}-{kind}-{key}.log"


def prune_logs(state_dir, keep_days=LOG_KEEP_DAYS):
    logs = Path(state_dir) / "logs"
    if not logs.is_dir():
        return
    cutoff = datetime.datetime.now().timestamp() - keep_days * 86400
    for f in logs.glob("*.log"):
        try:
            if f.stat().st_mtime < cutoff:
                f.unlink()
        except OSError:
            pass


def _context(path, text, parsed, source):
    reviewed = parsed["last_reviewed"].isoformat() if parsed["last_reviewed"] else "未実施"
    lines = [
        f"[LEARNING.md 読み込み済み] {path}（{parsed['items']} 項目、最終レビュー {reviewed}）",
        "以下はこのプロジェクトで過去のセッションから得た学び。プロジェクト固有の前提として従い、"
        "現状と矛盾する項目を見つけたら報告する。",
    ]
    if source != "compact":
        lines.append(f"最初の応答の冒頭に「LEARNING.md 読み込み済み（{parsed['items']} 項目）」と 1 行入れる。")
    lines += ["---", text.rstrip("\n")]
    return "\n".join(lines)


def _start_review(root, path, env, state_dir, today):
    key = state_key(root)
    stamp = Path(state_dir) / f"review-{key}.week"
    stamp.parent.mkdir(parents=True, exist_ok=True)
    stamp.write_text(iso_week(today) + "\n", encoding="utf-8")
    spawn(review_command(path, env), cwd=root, log_path=_log_path(state_dir, "review", key), env=env)


def handle_load(hook_input, env, state_dir=STATE_DIR, today=None):
    today = today or datetime.date.today()
    cwd = hook_input.get("cwd")
    if not cwd or not os.path.isdir(cwd):
        return None
    root = project_root(cwd) or cwd
    path = learning_path(root)
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError:
        return None
    parsed = parse_learning(text)
    source = hook_input.get("source")
    reviewed = parsed["last_reviewed"].isoformat() if parsed["last_reviewed"] else "未実施"
    message = f"LEARNING.md 読み込み済み（{parsed['items']} 項目、最終レビュー {reviewed}）"

    if source == "startup" and not env.get(AUTO_ENV):
        stamp = Path(state_dir) / f"review-{state_key(root)}.week"
        try:
            stamp_week = stamp.read_text(encoding="utf-8").strip()
        except OSError:
            stamp_week = None
        if review_due(parsed["last_reviewed"], stamp_week, today):
            _start_review(root, path, env, state_dir, today)
            message += "／今週の LEARNING レビューを背景で開始（→ SUGGESTION.md）"

    return {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": _context(path, text, parsed, source),
        },
        "systemMessage": message,
    }


def handle_extract(hook_input, env, state_dir=STATE_DIR):
    ok, _ = should_extract(hook_input, env)
    if not ok:
        return False
    cwd = hook_input["cwd"]
    root = project_root(cwd)
    path = learning_path(root)
    cmd = with_delay(learn_command(hook_input["session_id"], path, env), EXTRACT_DELAY_SEC)
    spawn(cmd, cwd=cwd, log_path=_log_path(state_dir, "learn", state_key(root)), env=env)
    return True


def _read_hook_input():
    try:
        data = json.load(sys.stdin)
    except (ValueError, OSError):
        return None
    return data if isinstance(data, dict) else None


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    cmd = argv[0] if argv else ""
    env = dict(os.environ)

    if cmd == "load":
        hook_input = _read_hook_input()
        if hook_input is None:
            return 0
        prune_logs(STATE_DIR)
        out = handle_load(hook_input, env)
        if out:
            json.dump(out, sys.stdout, ensure_ascii=False)
            sys.stdout.write("\n")
        return 0

    if cmd == "extract":
        hook_input = _read_hook_input()
        if hook_input is None:
            return 0
        handle_extract(hook_input, env)
        return 0

    if cmd == "path":
        cwd = argv[1] if len(argv) > 1 else os.getcwd()
        root = project_root(cwd) or os.path.abspath(cwd)
        print(learning_path(root))
        return 0

    if cmd == "review":
        cwd = argv[1] if len(argv) > 1 else os.getcwd()
        root = project_root(cwd) or os.path.abspath(cwd)
        path = learning_path(root)
        if not os.path.isfile(path):
            print(f"LEARNING.md がありません: {path}", file=sys.stderr)
            return 1
        _start_review(root, path, env, STATE_DIR, datetime.date.today())
        print(f"背景で /learn-review を開始しました: {path}")
        return 0

    print("usage: learning.py {load|extract|path [dir]|review [dir]}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
