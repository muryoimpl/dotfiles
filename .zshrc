export CC=/usr/local/bin/gcc-4.2

# add zsh packages config path.
export PGDATA=/usr/local/var/postgres
#rbenv setting
# eval "$(rbenv init -)"

export RSENSE_HOME=/opt/rsense-0.3

if [[ -f ~/.nodebrew/nodebrew ]]; then
  export PATH=$HOME/.nodebrew/current/bin:$PATH:
  nodebrew use v0.10.28
fi

# for oracle
export ORACLE_HOME=/Users/muryoimpl/opt/oracle
export PATH=$ORACLE_HOME/bin:$PATH
export DYLD_LIBRARY_PATH=$ORACLE_HOME/lib


## zsh load
source /usr/local/share/zsh/site-functions
source $HOME/.rbenv/completions/rbenv.zsh

source $HOME/.zsh.d/zshrc
source $HOME/.zsh.d/pecos

# add zsh plugins to use.
# load .zsh.d/plugins/*.zsh
plugins=(git git-flow git-extra gem osx ruby brew bundler node npm rails4 rails3 rake vi-mode )
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
