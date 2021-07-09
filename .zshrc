### Added by the Heroku Toolbelt
export TERMINAL=alacritty
# export PAGER='less'
export PAGER="nvim -c 'set ft=man' -"
export EDITOR='vim'
export LANG='ja_JP.UTF-8'
export HISTFILE=$HOME/.zsh_history

## メモリ上のヒストリ数。
## 大きな数を指定してすべてのヒストリを保存するようにしている。
HISTSIZE=10000000
## 保存するヒストリ数
SAVEHIST=$HISTSIZE
## ヒストリファイルにコマンドラインだけではなく実行時刻と実行時間も保存する。
setopt extended_history
## 同じコマンドラインを連続で実行した場合はヒストリに登録しない。
setopt hist_ignore_dups
## スペースで始まるコマンドラインはヒストリに追加しない。
setopt hist_ignore_space
## すぐにヒストリファイルに追記する。
setopt inc_append_history
## zshプロセス間でヒストリを共有する。
setopt share_history
## C-sでのヒストリ検索が潰されてしまうため、出力停止・開始用にC-s/C-qを使わない。
setopt no_flow_control

# for golang
export GOPATH=$HOME/go
export GOENV_ROOT="$HOME/.goenv"

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

export PATH=$GOENV_ROOT/shims:$GOENV_ROOT/bin:$HOME/.nodenv/bin:$HOME/.rbenv/bin:$GOPATH/bin:$HOME/local/bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH

eval "$(rbenv init -)"
eval "$(nodenv init -)"
eval "$(goenv init -)"
eval "$(pyenv init -)"
eval "$(direnv hook zsh)"

export GOROOT=''

## zsh load
source /usr/share/zsh/site-functions
source ~/.goenv/completions/goenv.zsh

eval "$(starship init zsh)"

bindkey -v
stty stop undef

zstyle ':completion:*:*:git:*' script ~/local/lib/completion/git-completion.bash
fpath=(~/local/lib/completion $fpath)
autoload -Uz compinit && compinit

# setup zplugin.zsh
source ~/.zinit/bin/zinit.zsh
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

############################################
# zsh plugins
############################################
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma/fast-syntax-highlighting
zinit load zsh-users/zsh-completions

export FZF_DEFAULT_OPTS='--no-height --no-reverse'
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
zinit ice from"gh-r" as"program"
zinit load junegunn/fzf-bin

export FZF_TMUX=1
zinit ice as:command pick"bin/fzf-tmux" multisrc"shell/key-bindings.zsh shell/completion.zsh"
zinit light "junegunn/fzf"

zinit ice as"completion"
zinit snippet https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker

zinit light "chrissicool/zsh-256color"

zinit ice as:command src"manydots-magic"
zinit light "knu/zsh-manydots-magic"

### alias
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"
alias la='exa -alhF'
alias g='git'
alias ctags='ctags -f .tags'
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
alias syua='paru --skipreview -Syu'
alias history-all='history -E 1'
alias hist='$(history -n 1 | peco)'
alias peco='TERM=xterm peco'
alias gbc='git checkout $(git branch | peco)'
alias dc='docker-compose'
alias gsw='git switch $(git branch | peco)'
alias fclist='fc-list : family style'
alias fd='fd --hidden --ignore-case'
alias rg='rg --hidden --no-ignore'
alias less='less -R'
alias cdmega='cd ~/local/MEGASync'

if [[ -f ~/local/work.zsh ]]; then
  source ~/local/work.zsh
else
  # for rootless docker
  # export PATH=/home/muryoimpl/bin:$PATH
  # export DOCKER_HOST=unix:///run/user/1000/docker.sock
fi

set bell-style none

neofetch
