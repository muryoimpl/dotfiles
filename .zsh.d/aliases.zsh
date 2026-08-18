### var
SUTRA_DIR=$HOME/local/MEGAsync/sutras-copying/

### alias
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"
alias g='git'
alias ctags='ctags --exclude="@${HOME}/.ctagsignore"'
alias gst='git status'
alias gco='git checkout'
alias gdd='git diff'
alias gdc='git diff --cached'
alias gba='git branch -a'
alias gcm='git commit --verbose'
alias gad='git add'
alias gadd='git add'
alias gl='git log'
alias be='bundle exec'
alias bundle='nocorrect bundle'
alias ghql='cd $(ghq list -p | peco)'
alias gb='git branch'
alias gsed='sed'
alias syua='yay -Syuu && yay -Syua --debug'
alias history-all='history -E 1'
alias hist='$(history -n 1 | peco)'
alias peco='TERM=xterm peco'
alias gbc='git checkout $(git branch | peco)'
alias dc='docker-compose'
alias gsw='git switch $(git branch | peco)'
alias less='less -R'
alias sutra='cd $(find $SUTRA_DIR -mindepth 1 -maxdepth 1 -type d | peco)'
alias sshl='ssh $(grep -w Host ~/.ssh/config | awk "{print $2}" | peco)'
alias nvimdiff='nvim -d'
alias agl='ag -l'
alias la='eza -lbhgUma'
alias spf='spf -c ~/.config/superfile/config.toml'
alias presenterm='presenterm --config-file ~/.config/presenterm/config.yaml'
alias sfzf='fzf -e '
alias fzfp='fzf --preview "bat --color=always {} 2>/dev/null"'
alias devc='devcontainer'
alias tmux-switch='tmux list-sessions | peco | cut -d: -f1 | xargs tmux switch-client -t'
alias gwl='git worktree list'

if is_macos; then
  alias abrew='arch -arm64 brew'
  alias xbrew='arch -x86_64 brew'
  alias fos='foreman start'
  alias fclist='fc-list : family style'

  # export PATH="/opt/homebrew/opt/openssl@1.1/bin:$PATH"
  export PATH="/opt/homebrew/opt/openssl@3/bin:$PATH"
  export PATH="/opt/homebrew/opt/mysql@5.7/bin:$PATH"
  export PATH="/opt/homebrew/opt/imagemagick@6/bin:$PATH"
  export PATH="/Applications/MEGAcmd.app/Contents/MacOS:$PATH"
  export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
  export PATH="/opt/homebrew/opt/bison/bin:$PATH"
  export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
  export PATH="/opt/homebrew/opt/curl/bin:$PATH"

  export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib -L/opt/homebrew/opt/curl/lib -L/opt/homebrew/opt/postgresql@16/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/openssl@3/include -I/opt/homebrew/opt/postgresql@16/include -I/opt/homebrew/opt/curl/include"
  export RUBY_CONFIGURE_OPTS="--disable-shared --enable-yjit --disable-install-doc --disable-install-rdoc --with-libyaml-dir=$(brew --prefix libyaml) --with-openssl-dir=$(brew --prefix openssl@3) --with-readline-dir=$(brew --prefix readline)"

  alias zellij='zellij options --copy-command pbcopy'
elif is_linux; then
  alias fclist='fc-list : family style'
  alias fd='fd --hidden --ignore-case'
  alias rg='rg --hidden --no-ignore'
  alias cdmega='cd ~/local/MEGASync'
  alias zoom='QT_QPA_PLATFORM=xcb zoom'
  # export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"

  alias pc='podman-compose'
  alias zellij='zellij options --copy-command wl-copy'
  alias locals3='aws --endpoint-url=http://localhost:9090 --profile s3mock s3'
elif is_win; then
  alias ssh='ssh.exe'
  alias ssh-add='ssh-add.exe'
  alias ssh-addl='ssh-add.exe -l'
  alias op='op.exe'

  alias fclist='fc-list : family style'
  alias fd='fd --hidden --ignore-case'
  alias rg='rg --hidden --no-ignore'
  alias zellij='zellij options --copy-command xclip -selection clipboard'
  alias locals3='aws --endpoint-url=http://localhost:9090 --profile s3mock s3'
fi

# yazi shortcut function
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

_cdwt() {
  local dir
  dir=$(
    git-wt |
      fzf --header-lines=1 |
      awk '{if ($1 == "*") print $2; else print $1}'
  ) || return

  [[ -n "$dir" ]] && cd -- "$dir"
}
alias cdwt='_cdwt'

# git worktree を peco で選んで cd する。
# peco は表示列の限定ができないため、一覧にはフルパスを載せず
# 行頭のインデックス番号経由で paths 配列からフルパスを引く。
_gwt() {
  local -a paths rows
  local line p sha br

  while IFS= read -r line; do
    case "$line" in
      'worktree '*) p="${line#worktree }"; sha=''; br='' ;;
      'HEAD '*)     sha="${line#HEAD }" ;;
      'branch '*)   br="${${line#branch }#refs/heads/}" ;;
      'detached')   br="${sha[1,7]}" ;;
      'bare')       br='(bare)' ;;
      '')  # レコード終端
        [[ -n "$p" ]] || continue
        paths+=("$p")
        rows+=("${#paths}"$'\t'"${p:h:t}/${p:t}"$'\t'"$br")
        p=''
        ;;
    esac
  done < <(git worktree list --porcelain) || return

  (( ${#paths} )) || return

  local idx
  # peco は複数選択できるが cd 先は 1 つなので先頭行だけ採用する
  idx=$(print -rl -- "${rows[@]}" | column -t -s $'\t' | peco | awk '{print $1; exit}') || return

  [[ -n "$idx" ]] && cd -- "${paths[$idx]}"
}
alias gwt='_gwt'

# ~/.claude/prompt_history.jsonl からプロンプト概要とセッション ID を peco で選び、
# 選択した session_id を標準出力する。例) claude --resume $(csid)
# デフォルトは現在のカレントディレクトリ ($PWD) で実行したエントリのみに絞り込む。
# 全件から選びたいときは `-a` / `--all` を渡す。
_csid() {
  local hist="$HOME/.claude/prompt_history.jsonl"
  [[ -f "$hist" ]] || { print -u2 "no history: $hist"; return 1; }

  local all=0
  case "${1:-}" in
    -a|--all) all=1 ;;
    '') ;;
    *) print -u2 "usage: csid [-a|--all]"; return 1 ;;
  esac

  local rows
  rows=$(
    tac -- "$hist" |
      jq -r --arg pwd "$PWD" --argjson all "$all" '
        select($all == 1 or .cwd == $pwd) |
        [
          .timestamp,
          .session_id,
          (.cwd_tail // ((.cwd // "") | split("/") | map(select(length > 0)) | last) // "-"),
          (.prompt | gsub("\\s+"; " ") | .[0:80])
        ] | @tsv
      ' |
      awk -F'\t' '!seen[$2]++'
  ) || return

  if [[ -z "$rows" ]]; then
    if (( all )); then
      print -u2 "no entry in $hist"
    else
      print -u2 "no entry for $PWD (use 'csid -a' for all)"
    fi
    return 1
  fi

  # session_id は peco の一覧では邪魔なので表示せず、内部の配列で行と対応づける
  # ディレクトリ名は $PWD で絞っているときは自明なので --all のときだけ表示する
  local -a sids disp
  local ts sid tail prompt
  while IFS=$'\t' read -r ts sid tail prompt; do
    sids+=("$sid")
    if (( all )); then
      disp+=("$ts"$'\t'"$tail"$'\t'"$prompt")
    else
      disp+=("$ts"$'\t'"$prompt")
    fi
  done <<< "$rows"

  local -a shown
  shown=("${(@f)$(print -rl -- "${disp[@]}" | column -t -s $'\t')}")

  local sel
  # peco は複数選択できるが session_id は 1 つなので先頭行だけ採用する
  sel=$(print -rl -- "${shown[@]}" | peco | head -n 1) || return
  [[ -n "$sel" ]] || return

  local idx=${shown[(ie)$sel]}
  if (( idx > ${#shown} )); then
    print -u2 "failed to resolve session_id"
    return 1
  fi

  print -- "${sids[$idx]}"
}
alias csid='_csid'

# csid で選んだ session_id で claude --resume を実行する。
# 先頭の `-a` / `--all` は csid にそのまま渡し、残りの引数は claude に渡す。
# 例) cresume            現在のディレクトリの履歴から選んで resume
#     cresume -a         全履歴から選んで resume
#     cresume -- --model opus  claude に追加の引数を渡す
_cresume() {
  local -a csid_args
  case "${1:-}" in
    -a|--all) csid_args=("$1"); shift ;;
  esac
  [[ "${1:-}" == '--' ]] && shift

  local sid
  sid=$(_csid "${csid_args[@]}") || return
  [[ -n "$sid" ]] || return

  claude --resume "$sid" "$@"
}
alias cresume='_cresume'
