### Added by the Heroku Toolbelt
export PAGER='less'
# export PAGER="nvim -c 'set ft=man' -"
export EDITOR='vim'
export LANG='ja_JP.UTF-8'
export HISTFILE=$HOME/.zsh_history
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$GOBIN:$PATH
export YABAI_CERT=yabai-cert

source $HOME/.zsh.d/utils.zsh

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
  zstyle ':completion:*:*:tig:*' script /usr/share/bash-completion/completions/tig
fi

fpath=(~/local/lib/completion $fpath)
autoload -Uz compinit && compinit

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

source $HOME/.zsh.d/aliases.zsh
source $HOME/.zsh.d/zinit.zsh

set bell-style none

neofetch
