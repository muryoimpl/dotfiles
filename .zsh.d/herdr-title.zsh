# herdr の tab / pane に tmux の automatic-rename 相当のラベルを自動で付ける。
#
# herdr 0.8.0 のタブラベルは custom_name が未設定なら位置番号 (1, 2, 3...) を出すだけで、
# cwd も実行中プロセス名も OSC タイトルも参照しない (src/workspace.rs tab_display_name)。
# タブバーの行構成を変える config キーも存在しないため、外側から herdr CLI を叩いて補う。
#
#   preexec -> "<cmd>"    (コマンドを実行したとき)
#
# ディレクトリ名は付けない。workspace をディレクトリ単位で分ける運用にしたことで
# workspace 側に出るようになり、タブ名に入れると重複表示になるため。
#
# precmd では rename しない。プロンプトに戻ったときのラベルからディレクトリ名を
# 外すと空になるが、herdr tab rename に --clear がなく (herdr pane rename にはある)、
# 空文字を送っても custom_name が Some("") になってタブ名が空白になるだけで
# 位置番号には戻せない (src/app/api/tabs.rs handle_tab_rename)。そのため
# プロンプトに戻ったあとも直前のコマンド名が残る。一度もコマンドを打っていない
# タブは herdr 既定の位置番号のまま。
#
# タブ名は focus 中の pane にのみ追従する。claude を走らせている pane の隣で
# ls を打っただけでタブ名が奪われるのを防ぐため。
# HERDR_TITLE_TAB_FOLLOWS_FOCUS=0 にすると「最後に動いた pane が勝つ」挙動になる。

[[ -o interactive ]] || return 0
[[ -n ${HERDR_ENV:-} && -n ${HERDR_TAB_ID:-} && -n ${HERDR_PANE_ID:-} ]] || return 0
builtin command -v herdr >/dev/null 2>&1 || return 0
[[ -n ${_herdr_title_loaded:-} ]] && return 0

typeset -g _herdr_title_loaded=1

: ${HERDR_TITLE_TAB_FOLLOWS_FOCUS:=1}
: ${HERDR_TITLE_MAX_WIDTH:=24}

typeset -g _herdr_title_last_tab=''
typeset -g _herdr_title_last_pane=''

autoload -Uz add-zsh-hook

# 表示幅 (CJK は 2 桁) で切り詰めて REPLY に返す
_herdr_title_truncate() {
  local s=$1 max=$2
  if (( ${(m)#s} <= max )); then
    REPLY=$s
    return 0
  fi
  while (( ${#s} > 0 && ${(m)#s} > max - 1 )); do
    s=${s[1,-2]}
  done
  REPLY="${s}…"
}

# コマンド行から表示するコマンド名を求めて REPLY に返す
_herdr_title_cmd_name() {
  emulate -L zsh
  setopt extended_glob
  local -a words
  words=(${(z)1})
  local w
  while (( $#words )); do
    w=$words[1]
    # 先頭の環境変数代入 (FOO=bar) を読み飛ばす
    if [[ $w == [A-Za-z_][A-Za-z0-9_]#=* ]]; then
      shift words
      continue
    fi
    # ラッパーは basename で判定する (/usr/bin/env のような書き方に対応)。
    # nocorrect / noglob は aliases.zsh の `alias bundle='nocorrect bundle'` 等で
    # 展開後の先頭に現れる
    case ${w:t} in
      (sudo|doas|command|builtin|exec|env|time|nohup|nocorrect|noglob) shift words ;;
      (*)                                                              break ;;
    esac
  done
  w=${words[1]:-}
  w=${w//[\'\"]/}
  w=${w#\\}   # \ls のようなエスケープ付き呼び出し
  [[ -n $w ]] || return 1
  # シェル構文はそのまま出す (basename を取ると意味が壊れるため)
  case $w in
    (if|for|while|until|case|select|function|repeat|do|then|'{'|'('|'!'|'['|'[[')
      REPLY=$w
      return 0 ;;
  esac
  REPLY="${w:t}"
}

# 自 pane が focus されているか。herdr pane current の JSON を部分一致で見る。
# JSON 文字列の中では " が \" にエスケープされるため、terminal_title 等の値が
# "focused":true という並びを含むことはなく、キーとしての一致だけが成立する。
_herdr_title_pane_focused() {
  (( HERDR_TITLE_TAB_FOLLOWS_FOCUS )) || return 0
  local out
  out=$(builtin command herdr pane current --current 2>/dev/null) || return 1
  [[ $out == *'"focused":true'* ]]
}

_herdr_title_apply() {
  local label=$1
  [[ -n $label ]] || return 0

  local REPLY
  _herdr_title_truncate "$label" $HERDR_TITLE_MAX_WIDTH
  label=$REPLY
  [[ -n $label ]] || return 0

  # 定常状態では herdr を一度も呼ばない
  [[ $label == $_herdr_title_last_pane && $label == $_herdr_title_last_tab ]] && return 0

  if [[ $label != $_herdr_title_last_pane ]]; then
    if builtin command herdr pane rename "$HERDR_PANE_ID" "$label" >/dev/null 2>&1; then
      _herdr_title_last_pane=$label
    fi
  fi

  if [[ $label != $_herdr_title_last_tab ]] && _herdr_title_pane_focused; then
    if builtin command herdr tab rename "$HERDR_TAB_ID" "$label" >/dev/null 2>&1; then
      _herdr_title_last_tab=$label
    fi
  fi

  return 0
}

_herdr_title_preexec() {
  local REPLY
  _herdr_title_cmd_name "${3:-$1}" || return 0
  _herdr_title_apply "$REPLY"
}

add-zsh-hook preexec _herdr_title_preexec
