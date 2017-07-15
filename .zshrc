# export CC=/usr/local/bin/gcc-4.2

# add zsh packages config path.
# export PGDATA=/usr/local/var/postgres

export GOPATH=$HOME/go
export GOENV_ROOT="$HOME/.goenv"

export PATH=$GOENV_ROOT/shims:$GOENV_ROOT/bin:$HOME/.nodenv/bin:$HOME/.exenv/bin:$HOME/.rbenv/bin:$GOPATH/bin:$HOME/local/bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH
eval "$(exenv init -)"
eval "$(nodenv init -)"
eval "$(goenv init -)"

# if [[ -f ~/.nodenv/bin/nodenv ]]; then
#   node_version=6.9.1
#   export NODENV_VERSION=${node_version}
#   echo "node version: $node_version"
# fi

## zsh load
source /usr/share/zsh/site-functions

source $HOME/.zsh.d/zshrc
source $HOME/.zsh.d/pecos

bindkey -v

### alias
alias gst='git status'
alias gco='git checkout'
alias gdd='git diff'
alias gdc='git diff --cached'
alias gba='git branch -a'
alias gcm='git commit'
alias gad='git add'
alias gadd='git add'
alias gl='git log'
alias ctg='ctags --langmap="Ruby:.rb" --exclude="*.js"  --exclude=".git*" -R .'
alias be='bundle exec'
alias bundle='nocorrect bundle'
alias ghql='cd $(ghq list -p | peco)'
alias gb='git branch'
alias tmux='TERM=xterm-256color tmux'

### Added by the Heroku Toolbelt
# export PATH="/usr/local/heroku/bin:$PATH"

source ~/.goenv/completions/goenv.zsh

source ~/.ghq/github.com/zsh-users/antigen/antigen.zsh
antigen bundle sorin-ionescu/prezto
