alias g='git'
alias gst='git status'
alias gco='git checkout'
alias gdd='git diff'
alias gdc='git diff --cached'
alias gba='git branch -a'
alias gcm='git commit --verbose'
alias gad='git add'
alias gadd='git add'
alias gl='git log'
alias gb='git branch'
alias gbc='git checkout $(git branch --format="%(refname:short)" | fzf)'
alias dc='docker-compose'
alias gsw='git switch $(git branch --format="%(refname:short)" | fzf)'

alias less='less -R'
alias nvimdiff='nvim -d'
alias rgl='rg -l'
alias la='eza -lbhgUma'
alias sfzf='fzf -e '
alias fzfp='fzf --preview "bat --color=always {} 2>/dev/null"'

__fzf_history_insert() {
  local cmd
  cmd=$(
    history |
      fzf --tac --no-sort --tiebreak=index |
      sed 's/^[[:space:]]*[0-9]\+[[:space:]]*//'
  ) || return

  # 現在の入力行に挿入
  READLINE_LINE=${cmd}
  READLINE_POINT=${#READLINE_LINE}
}

alias hist='__fzf_history_insert'

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
