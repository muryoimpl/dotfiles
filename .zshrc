OS_NAME="$(uname -r -o)"
DIST_NAME="$(cat /etc/issue)"

function is_linux() {
  [[ $OS_NAME =~ 'Linux' ]]
}

function is_macos() {
  [[ $OS_NAME =~ 'Darwin' ]]
}

function is_win() {
  [[ $OS_NAME =~ 'WSL2' ]]
}

function is_debian() {
  [[ $DIST_NAME =~ 'Debian' ]]
}

bindkey -v
stty stop undef

if is_macos; then
  zstyle ':completion:*:*:git:*' script /opt/homebrew/share/zsh/site-functions/git-completion.bash
  zstyle ':completion:*:*:tig:*' script /opt/homebrew/share/zsh/site-functions/tig-completion.bash
elif is_win; then
  zstyle ':completion:*:*:git:*' script ~/local/lib/completion/git-completion.bash
  zstyle ':completion:*:*:tig:*' script /usr/share/bash-completion/completions/tig
elif is_linux; then
  zstyle ':completion:*:*:git:*' script /usr/share/git/completion/git-completion.bash
  zstyle ':completion:*:*:tig:*' script /usr/share/bash-completion/completions/tig
fi

[[ -d ~/local/lib/completion ]] && fpath=(~/local/lib/completion $fpath)
autoload -Uz compinit
# compinit の呼び出しは全 fpath 追加後（末尾の Docker 補完セクション）で 1 回だけ実行する

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

export PAGER='less'
export EDITOR='nvim'
export LANG='ja_JP.UTF-8'
export HISTFILE=$HOME/.zsh_history
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export YABAI_CERT=yabai-cert

# .zshenv で登録済みの項目を除いた PATH（rbenv/nodenv 本体の発見に必要な bin を含む）
export PATH=$HOME/.nodenv/bin:$HOME/.rbenv/bin:/usr/local/share/aclocal:/usr/sbin:/sbin:$PATH
export PATH=$HOME/.local/bin:$PATH
export TERMINAL=ghostty

if is_macos; then
  export PATH=/opt/homebrew/opt/bin:$PATH
elif is_win; then
  if is_debian; then
    export RBENV_ROOT=$HOME/.rbenv
  else
    export RBENV_ROOT=$HOME/local/.rbenv
  fi
fi

if builtin command -v rbenv > /dev/null; then
  eval "$(rbenv init - zsh)"
fi

if builtin command -v nodenv > /dev/null; then
  eval "$(nodenv init -)"
fi

if builtin command -v direnv > /dev/null; then
  eval "$(direnv hook zsh)"
fi

if builtin command -v starship > /dev/null; then
  eval "$(starship init zsh)"
fi

if git wt --version >/dev/null 2>&1; then
  eval "$(git wt --init zsh)"
else
  echo "git wt is not installed. Please install git wt for enhanced git status in the prompt."
fi

[ -f ~/.zsh.d/aliases.zsh ] &&  source $HOME/.zsh.d/aliases.zsh
[ -f ~/.zsh.d/zinit.zsh ] &&  source $HOME/.zsh.d/zinit.zsh

unsetopt beep

if builtin command -v fastfetch > /dev/null; then
  fastfetch
else
  neofetch
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Docker Desktop の CLI 補完（全 fpath 追加後に compinit を 1 回だけ実行）
fpath=($HOME/.docker/completions $fpath)
compinit

if builtin command -v tmux >/dev/null 2>&1; then
  if [ "$TMUX" = "" ]; then
      tmux attach;

      # detachしてない場合
      if [ $? ]; then
          tmux new -s main;
      fi
  fi
fi

if builtin command -v volta >/dev/null 2>&1; then
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
fi
