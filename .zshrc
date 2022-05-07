### Added by the Heroku Toolbelt
export PAGER='less'
# export PAGER="nvim -c 'set ft=man' -"
export EDITOR='vim'
export LANG='ja_JP.UTF-8'
export HISTFILE=$HOME/.zsh_history
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$GOBIN:$PATH

OS_NAME="$(uname)"

function is_linux() {
  [[ $OS_NAME == 'Linux' ]]
}

function is_macos() {
  [[ $OS_NAME == 'Darwin' ]]
}

if is_macos; then
  export TERMINAL=kitty

  echo 'Darwin'
  export PATH=/opt/homebrew/bin:$HOME/.nodenv/bin:$HOME/.rbenv/bin:$HOME/local/bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH
elif is_linux; then
  export TERMINAL=alacritty

  echo 'Linux'
  export PATH=$HOME/.nodenv/bin:$HOME/.rbenv/bin:$HOME/local/bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH
fi

eval "$(rbenv init -)"
eval "$(nodenv init -)"
eval "$(direnv hook zsh)"

eval "$(starship init zsh)"

## zsh load
if is_macos; then
  source /opt/homebrew/share/zsh/site-functions
elif is_linux; then
  source /usr/share/zsh/site-functions
fi

bindkey -v
stty stop undef

if is_macos; then
  zstyle ':completion:*:*:git:*' script /opt/homebrew/share/zsh/site-functions/git-completion.bash
  zstyle ':completion:*:*:tig:*' script /opt/homebrew/share/zsh/site-functions/tig-completion.bash
elif is_linux; then
  zstyle ':completion:*:*:git:*' script ~/local/lib/completion/git-completion.bash
fi

fpath=(~/local/lib/completion $fpath)
autoload -Uz compinit && compinit

# setup zplugin.zsh
if [ -e ~/.zinit/bin/zinit.zsh ]; then
  source ~/.zinit/bin/zinit.zsh
else
  source ~/.local/share/zinit/zinit.git/zinit.zsh
fi
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

############################################
# zsh plugins
############################################
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting
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

### pure zsh config
### メモリ上のヒストリ数。
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
alias syua='paru --skipreview -Syu'
alias history-all='history -E 1'
alias hist='$(history -n 1 | peco)'
alias peco='TERM=xterm peco'
alias gbc='git checkout $(git branch | peco)'
alias dc='docker-compose'
alias gsw='git switch $(git branch | peco)'
alias less='less -R'


if is_macos; then
  alias abrew='arch -arm64 brew'
  alias xbrew='arch -x86_64 brew'
  alias fos='foreman start'
  alias fclist='fc-list : family style'
  alias la='exa -alhF'

  export PATH="/opt/homebrew/opt/openssl@1.1/bin:$PATH"
  export PATH="/opt/homebrew/opt/mysql@5.7/bin:$PATH"
  export PATH="/opt/homebrew/opt/imagemagick@6/bin:$PATH"
elif is_linux; then
  alias fclist='fc-list : family style'
  alias la='exa -alhF'
  alias fd='fd --hidden --ignore-case'
  alias rg='rg --hidden --no-ignore'
  alias cdmega='cd ~/local/MEGASync'
fi

set bell-style none

neofetch

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk
