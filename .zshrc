# export CC=/usr/local/bin/gcc-4.2

# add zsh packages config path.
export PGDATA=/usr/local/var/postgres

export GOPATH=$HOME/gocode

export PATH=$HOME/.exenv/bin:$HOME/.rbenv/bin:$HOME/.nodebrew/bin:$GOPATH/bin:$HOME/local/bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH
eval "$(exenv init -)"
eval "$(rbenv init -)"

if [[ -f ~/.nodebrew/nodebrew ]]; then
  export PATH=$HOME/.nodebrew/current/bin:$PATH:
  nodebrew use v4.2.4
fi

## zsh load
source /usr/local/share/zsh/site-functions
source $HOME/.rbenv/completions/rbenv.zsh

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

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"
