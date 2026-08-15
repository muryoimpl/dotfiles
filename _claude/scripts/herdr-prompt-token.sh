#!/bin/sh
# UserPromptSubmit フック: 直近のプロンプト冒頭を herdr の pane metadata に報告し、
# sidebar の agent 行に $prompt token として「最新のプロンプト」を表示する。
#
# Claude Code の OSC タイトルはセッション開始時に一度決まったきり毎プロンプトでは
# 更新されないため、herdr 内蔵の terminal_title / terminal_title_stripped だけでは
# 初回プロンプト由来の要約が出続け、いま何を指示したのかが分からない。そこで
# プロンプト送信のたびに `herdr pane report-metadata --token prompt=...` を叩く。
#
# 対になる設定は dotconfig 側 ~/.config/herdr/config.toml の
# [ui.sidebar.agents.rows_by_agent] claude で、OSC タイトル行 (pane の目印) と
# $prompt 行 (最新の指示) を両方出している。
#
# agent 由来のプロンプト:
#   `herdr agent prompt` で他 agent から投げられたプロンプトでも UserPromptSubmit は
#   発火するため、そのままでは自分が打ったものと区別できない。自 pane が focus
#   されていれば人間が打ったもの、そうでなければ agent 由来とみなし、後者には
#   先頭に HERDR_PROMPT_AGENT_MARKER (既定 "« ") を付けて表示する。
#   focus 判定の手法は ~/.zsh.d/herdr-title.zsh の _herdr_title_pane_focused と同じ。
#
# herdr 管理の ~/.claude/hooks/herdr-agent-state.sh は integration の再インストールで
# 上書きされるため触らない。こちらは dotfiles 管理下の scripts/ に置いている
# (~/.claude/scripts は dotfiles/_claude/scripts への symlink)。
#
# 注意:
#   - stdout に何も出力しないこと。UserPromptSubmit の stdout は Claude のコンテキストに
#     追加されるため、herdr CLI の出力も含めてすべて捨てる
#   - 必ず exit 0 すること。非 0 (特に 2) はプロンプト送信自体をブロックする
#
# 表示幅は HERDR_PROMPT_MAX_WIDTH で調整できる (既定 28 / sidebar_width = 32 に合わせた値)。
# marker を付ける場合も、marker 込みでこの幅に収まるよう詰める。

hook_input_file="$(mktemp "${TMPDIR:-/tmp}/herdr-claude-prompt.XXXXXX")" || exit 0
trap 'rm -f "$hook_input_file"' EXIT HUP INT TERM
cat >"$hook_input_file" 2>/dev/null || true

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# 自 pane が focus されていれば人間が打ったもの、そうでなければ herdr agent prompt 等で
# agent 側から投げられたものとみなす。JSON 文字列中の " は \" にエスケープされるため、
# terminal_title 等の値が "focused":true という並びを含むことはなく、キーとしての一致
# だけが成立する (~/.zsh.d/herdr-title.zsh の _herdr_title_pane_focused と同じ理屈)。
# 照会に失敗したときは marker を付けない self 側に倒す。
herdr_prompt_origin=self
if herdr_focus_json="$(herdr pane current --current 2>/dev/null)"; then
  case "$herdr_focus_json" in
    *'"focused":true'*)  herdr_prompt_origin=self ;;
    *'"focused":false'*) herdr_prompt_origin=agent ;;
    # 読めない応答は marker を付けない側に倒す (herdr の exit code に依存しない)
    *)                   herdr_prompt_origin=self ;;
  esac
fi

HERDR_HOOK_INPUT_FILE="$hook_input_file" \
HERDR_PROMPT_ORIGIN="$herdr_prompt_origin" \
python3 - >/dev/null 2>&1 <<'PY'
import json
import os
import re
import subprocess
import time
import unicodedata

SOURCE = "claude-prompt"
TOKEN = "prompt"

pane_id = os.environ.get("HERDR_PANE_ID")
hook_input_file = os.environ.get("HERDR_HOOK_INPUT_FILE")
try:
    max_width = int(os.environ.get("HERDR_PROMPT_MAX_WIDTH", "28"))
except ValueError:
    max_width = 28
if not pane_id or not hook_input_file or max_width < 2:
    raise SystemExit(0)

try:
    with open(hook_input_file, encoding="utf-8") as handle:
        hook_input = json.load(handle)
except Exception:
    raise SystemExit(0)
if not isinstance(hook_input, dict):
    raise SystemExit(0)

# subagent の入力は pane の代表プロンプトではないので無視する
# (herdr-agent-state.sh も agent_id 付きの入力を同様に捨てている)
if hook_input.get("agent_id"):
    raise SystemExit(0)

prompt = hook_input.get("prompt")
if not isinstance(prompt, str):
    raise SystemExit(0)

# 改行・タブ・制御文字を空白に潰してから連続空白を 1 つに畳む。
# sidebar は 1 行表示なので、生の改行が混ざると行が壊れる。
text = "".join(
    " " if unicodedata.category(ch) in ("Cc", "Cf", "Zl", "Zp") else ch
    for ch in prompt
)
text = re.sub(r"\s+", " ", text).strip()
if not text:
    raise SystemExit(0)


def width(s):
    """端末上の表示幅。CJK 全角は 2 桁として数える。"""
    return sum(
        2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
        for ch in s
    )


# agent 由来のプロンプトだけ marker を前置する。marker も幅を食うので、
# 詰める段階で先に差し引いておき、marker 込みで max_width に収まるようにする。
marker = ""
if os.environ.get("HERDR_PROMPT_ORIGIN") == "agent":
    marker = os.environ.get("HERDR_PROMPT_AGENT_MARKER", "« ")
budget = max_width - width(marker)
if budget < 2:
    marker = ""
    budget = max_width

if width(text) > budget:
    # 末尾の "…" (1 桁) の分を残して詰める
    kept = []
    used = 0
    for ch in text:
        w = width(ch)
        if used + w > budget - 1:
            break
        kept.append(ch)
        used += w
    text = "".join(kept) + "…"

text = marker + text

try:
    subprocess.run(
        [
            "herdr", "pane", "report-metadata", pane_id,
            "--source", SOURCE,
            # この metadata は claude 用だと宣言しておく。pane の claude が終了した
            # ときに herdr 側 (terminal/state.rs の agent_metadata.retain) が
            # 自動で捨ててくれるので、shell に戻った pane に古いプロンプトが
            # 残り続けない。終了直後に遅れて届いた報告も同じ経路で弾かれる。
            "--agent", "claude",
            "--token", "{}={}".format(TOKEN, text),
            # 単調増加する seq で、報告が前後しても古い値が勝たないようにする
            "--seq", str(time.time_ns()),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=3,
        check=False,
    )
except Exception:
    pass
PY

exit 0
