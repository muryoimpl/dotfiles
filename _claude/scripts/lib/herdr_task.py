#!/usr/bin/env python3
"""claude のセッションに Linear の issue ID を紐付け、herdr に表示する。

呼び出しは ~/.claude/scripts/herdr-task.sh 経由。サブコマンド:

  label   UserPromptSubmit hook。issue ID を確定し tab / pane に反映する
  done    Stop hook。完了の合い言葉を検出したら "✓" を付ける
  set     issue ID を手で上書きする
  list    いまどこでどのタスクが走っているかを一覧する

「どのタブでどのタスクか」が分からなくなる問題への対処。herdr のタブラベルは
custom_name か位置番号の 2 択で cwd もプロセス名も見ないため、外から
`herdr tab rename` と `herdr pane report-metadata` を叩いて補う。

state:
  ~/.claude/state/task-<session_id>.json  セッション単位 (issue / done / 位置)
  ~/.claude/state/tab-<tab_id>.txt        タブ単位のラベル素材

tab-*.txt を別に持つのは、pane metadata の token に --agent claude を付けており
claude 終了時に herdr 側で自動破棄されるため。claude を終了したあとも
~/.zsh.d/herdr-title.zsh がタブ名に issue ID を残せるようにファイルで保持する。
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from extract_issue import extract, load_teams  # noqa: E402

STATE_DIR = Path.home() / ".claude" / "state"
PROMPT_LOG = Path.home() / ".claude" / "prompt_history.jsonl"
SOURCE = "claude-task"
DONE_MARK = "🔚Turrrrrrrrrrn end.🔚"
DONE_PREFIX = "✓ "
HERDR_TIMEOUT = 3


# --------------------------------------------------------------------------
# herdr CLI
# --------------------------------------------------------------------------


def herdr_bin():
    return os.environ.get("HERDR_BIN_PATH") or "herdr"


def herdr(*args, capture=False):
    """herdr CLI を叩く。失敗は握り潰す (hook を絶対に落とさない)。"""
    try:
        result = subprocess.run(
            [herdr_bin(), *args],
            stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=HERDR_TIMEOUT,
            check=False,
        )
    except Exception:
        return None
    if not capture:
        return result.returncode == 0
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout.decode("utf-8"))
    except Exception:
        return None


# --------------------------------------------------------------------------
# state
# --------------------------------------------------------------------------


def state_path(session_id):
    return STATE_DIR / "task-{}.json".format(session_id)


def tab_label_path(tab_id):
    return STATE_DIR / "tab-{}.txt".format(tab_id.replace(":", "_"))


def read_state(session_id):
    try:
        with open(state_path(session_id), encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def write_state(session_id, data):
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        tmp = state_path(session_id).with_suffix(".json.tmp")
        tmp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        tmp.replace(state_path(session_id))
    except Exception:
        pass


def write_tab_label(tab_id, label):
    if not tab_id:
        return
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        tab_label_path(tab_id).write_text(label + "\n", encoding="utf-8")
    except Exception:
        pass


# --------------------------------------------------------------------------
# 表示への反映
# --------------------------------------------------------------------------


def apply_label(issue, done=False):
    """tab / pane / state ファイルに issue ID を反映する (べき等)。"""
    tab_id = os.environ.get("HERDR_TAB_ID", "")
    pane_id = os.environ.get("HERDR_PANE_ID", "")
    label = (DONE_PREFIX + issue) if done else issue

    if tab_id:
        herdr("tab", "rename", tab_id, label)
    if pane_id:
        herdr(
            "pane",
            "report-metadata",
            pane_id,
            "--source",
            SOURCE,
            # claude 用の metadata だと宣言しておくと、claude 終了時に
            # herdr 側が自動で捨ててくれる (herdr-prompt-token.sh と同じ)
            "--agent",
            "claude",
            "--display-agent",
            label,
            "--token",
            "task={}".format(label),
            # 報告が前後しても古い値が勝たないよう単調増加の seq を付ける
            "--seq",
            str(time.time_ns()),
        )
    write_tab_label(tab_id, label)
    return label


# --------------------------------------------------------------------------
# issue ID の検出
# --------------------------------------------------------------------------


def git_branch(cwd):
    if not cwd or not os.path.isdir(cwd):
        return ""
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "symbolic-ref", "--short", "HEAD"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=HERDR_TIMEOUT,
            check=False,
        )
    except Exception:
        return ""
    return result.stdout.decode("utf-8", "replace").strip() if result.returncode == 0 else ""


def detect_issue(prompt, cwd):
    """issue ID を検出して (issue, source) を返す。優先順はブランチ > cwd > プロンプト。

    worktree 側の claude は親と別セッションで worktree state を持たないが、
    cwd のブランチから確実に取れる。
    """
    teams = load_teams(cwd=cwd)

    branch = git_branch(cwd)
    issue = extract(branch, teams=teams, ignore_case=True)
    if issue:
        return issue, "branch"

    issue = extract(os.path.basename(cwd or ""), teams=teams, ignore_case=True)
    if issue:
        return issue, "cwd"

    # プロンプト本文は誤検出の温床なので、allowlist があるときだけ
    # 小文字表記も許す。allowlist が無いときは大文字表記のみ拾う。
    issue = extract(prompt, teams=teams, ignore_case=bool(teams))
    if issue:
        return issue, "prompt"

    return None, None


# --------------------------------------------------------------------------
# サブコマンド
# --------------------------------------------------------------------------


def read_hook_input():
    try:
        raw = sys.stdin.read()
    except Exception:
        return {}
    try:
        data = json.loads(raw)
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def cmd_label():
    """UserPromptSubmit hook。stdout には何も出さず、必ず 0 で終わる。"""
    hook = read_hook_input()
    # subagent の入力は pane の代表タスクではない (herdr-prompt-token.sh と同じ判定)
    if hook.get("agent_id"):
        return 0

    session_id = hook.get("session_id") or ""
    if not session_id:
        return 0

    cwd = hook.get("cwd") or ""
    prompt = hook.get("prompt") or ""
    if not isinstance(prompt, str):
        prompt = ""

    state = read_state(session_id)
    issue = state.get("issue")

    if not issue:
        issue, source = detect_issue(prompt, cwd)
        if not issue:
            return 0
        state = {
            "issue": issue,
            "source": source,
            "done": False,
            "workspace_id": os.environ.get("HERDR_WORKSPACE_ID", ""),
            "tab_id": os.environ.get("HERDR_TAB_ID", ""),
            "pane_id": os.environ.get("HERDR_PANE_ID", ""),
            "cwd": cwd,
        }
    else:
        # タブを移動した場合に備えて位置は毎回更新する
        state["workspace_id"] = os.environ.get("HERDR_WORKSPACE_ID", "")
        state["tab_id"] = os.environ.get("HERDR_TAB_ID", "")
        state["pane_id"] = os.environ.get("HERDR_PANE_ID", "")

    state["updated_at"] = time.strftime("%F %T %Z")
    write_state(session_id, state)

    # herdr-title.zsh にタブ名を奪われても戻るよう、毎プロンプトで貼り直す
    apply_label(issue, done=bool(state.get("done")))
    return 0


def transcript_path_for(hook, session_id):
    path = hook.get("transcript_path") or ""
    if path and os.path.isfile(path):
        return path
    # record-prompt.sh が session_id ごとに transcript_path を保存している
    try:
        found = ""
        with open(PROMPT_LOG, encoding="utf-8") as handle:
            for line in handle:
                try:
                    row = json.loads(line)
                except Exception:
                    continue
                if row.get("session_id") == session_id and row.get("transcript_path"):
                    found = row["transcript_path"]
        if found and os.path.isfile(found):
            return found
    except Exception:
        pass
    return ""


def last_turn_assistant_text(path):
    """直近のユーザープロンプト以降の assistant テキストを連結して返す。

    それより前の turn まで遡ると、過去に出した合い言葉を拾ってしまうため。
    """
    try:
        with open(path, encoding="utf-8") as handle:
            rows = [line for line in handle]
    except Exception:
        return ""

    chunks = []
    for line in reversed(rows):
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except Exception:
            continue
        if row.get("isSidechain"):
            continue

        message = row.get("message") or {}
        content = message.get("content")

        if row.get("type") == "assistant":
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        chunks.append(block.get("text") or "")
            elif isinstance(content, str):
                chunks.append(content)
            continue

        if row.get("type") == "user":
            # tool_result だけの user 行は turn の継続。人間の入力で打ち切る
            if isinstance(content, str):
                break
            if isinstance(content, list) and any(
                isinstance(block, dict) and block.get("type") == "text"
                for block in content
            ):
                break

    return "\n".join(reversed(chunks))


def cmd_done():
    """Stop hook。完了の合い言葉を検出したときだけ ✓ を付ける。"""
    hook = read_hook_input()
    if hook.get("agent_id"):
        return 0

    session_id = hook.get("session_id") or ""
    if not session_id:
        return 0

    state = read_state(session_id)
    issue = state.get("issue")
    if not issue or state.get("done"):
        return 0

    path = transcript_path_for(hook, session_id)
    if not path:
        return 0

    if DONE_MARK not in last_turn_assistant_text(path):
        return 0

    state["done"] = True
    state["updated_at"] = time.strftime("%F %T %Z")
    write_state(session_id, state)

    label = apply_label(issue, done=True)
    body = os.path.basename(state.get("cwd") or "") or "完了"
    herdr("notification", "show", label, "--body", body, "--sound", "done")
    return 0


def session_id_for_current_pane():
    pane_id = os.environ.get("HERDR_PANE_ID", "")
    if not pane_id:
        return ""
    data = herdr("pane", "get", pane_id, capture=True) or {}
    pane = (data.get("result") or {}).get("pane") or {}
    return ((pane.get("agent_session") or {}).get("value")) or ""


def cmd_set(argv):
    if not argv:
        print("usage: herdr-task.sh set <ISSUE-ID>", file=sys.stderr)
        return 1
    issue = argv[0].strip().upper()
    if not issue:
        return 1

    session_id = session_id_for_current_pane()
    if session_id:
        state = read_state(session_id)
        state.update(
            {
                "issue": issue,
                "source": "manual",
                "done": False,
                "workspace_id": os.environ.get("HERDR_WORKSPACE_ID", ""),
                "tab_id": os.environ.get("HERDR_TAB_ID", ""),
                "pane_id": os.environ.get("HERDR_PANE_ID", ""),
                "updated_at": time.strftime("%F %T %Z"),
            }
        )
        state.setdefault("cwd", os.getcwd())
        write_state(session_id, state)

    label = apply_label(issue, done=False)
    print(label)
    return 0


def cmd_list():
    agents = ((herdr("agent", "list", capture=True) or {}).get("result") or {}).get(
        "agents"
    ) or []
    tabs = ((herdr("tab", "list", capture=True) or {}).get("result") or {}).get(
        "tabs"
    ) or []
    workspaces = (
        (herdr("workspace", "list", capture=True) or {}).get("result") or {}
    ).get("workspaces") or []

    ws_label = {w.get("workspace_id"): w.get("label") or "" for w in workspaces}
    tab_by_id = {t.get("tab_id"): t for t in tabs}
    live_tab_ids = set(tab_by_id)

    by_session = {}
    for agent in agents:
        value = (agent.get("agent_session") or {}).get("value")
        if value:
            by_session[value] = agent

    icon = {"working": "●", "blocked": "!", "idle": "○", "done": "✓", "unknown": "·"}
    rows = []
    for path in sorted(STATE_DIR.glob("task-*.json")):
        session_id = path.name[len("task-") : -len(".json")]
        try:
            with open(path, encoding="utf-8") as handle:
                state = json.load(handle)
        except Exception:
            continue
        if not isinstance(state, dict) or not state.get("issue"):
            continue

        agent = by_session.get(session_id)
        if agent:
            status = agent.get("agent_status") or "unknown"
            workspace_id = agent.get("workspace_id") or ""
            tab_id = agent.get("tab_id") or ""
            cwd = agent.get("cwd") or state.get("cwd") or ""
            prompt = (agent.get("tokens") or {}).get("prompt") or ""
        else:
            status = "done" if state.get("done") else "-"
            workspace_id = state.get("workspace_id") or ""
            tab_id = state.get("tab_id") or ""
            cwd = state.get("cwd") or ""
            prompt = ""

        if state.get("done"):
            status = "done"

        # タブラベルには issue ID が入っているので、ここでは位置だけを出す
        tab = tab_by_id.get(tab_id) or {}
        if tab.get("number"):
            tab_name = "#{}".format(tab["number"])
        elif tab_id:
            tab_name = tab_id.split(":")[-1]
        else:
            tab_name = "-"
        place = "{} / {}".format(ws_label.get(workspace_id, workspace_id) or "-", tab_name)
        rows.append(
            (
                icon.get(status, "-"),
                state["issue"],
                place,
                cwd.replace(str(Path.home()), "~"),
                prompt,
                bool(agent),
            )
        )

    if not rows:
        print("追跡中のタスクはありません。")
    else:
        rows.sort(key=lambda r: (not r[5], r[1]))
        widths = [max(len(str(r[i])) for r in rows) for i in range(5)]
        header = ("", "ISSUE", "WORKSPACE / TAB", "CWD", "PROMPT")
        widths = [max(widths[i], len(header[i])) for i in range(5)]
        print("  ".join(header[i].ljust(widths[i]) for i in range(5)).rstrip())
        for row in rows:
            print("  ".join(str(row[i]).ljust(widths[i]) for i in range(5)).rstrip())

    # 消えたタブのラベル素材を掃除する
    for path in STATE_DIR.glob("tab-*.txt"):
        tab_id = path.name[len("tab-") : -len(".txt")].replace("_", ":")
        if live_tab_ids and tab_id not in live_tab_ids:
            try:
                path.unlink()
            except OSError:
                pass

    if not load_teams():
        print(
            "\n注意: チームキーの allowlist が未設定です "
            "(~/.claude/linear-teams.txt)。誤検出を避けるため設定を推奨します。",
            file=sys.stderr,
        )
    return 0


def main(argv):
    if not argv:
        print("usage: herdr-task.sh {label|done|set <ISSUE>|list}", file=sys.stderr)
        return 1
    command, rest = argv[0], argv[1:]
    if command == "label":
        return cmd_label()
    if command == "done":
        return cmd_done()
    if command == "set":
        return cmd_set(rest)
    if command == "list":
        return cmd_list()
    print("unknown subcommand: {}".format(command), file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
