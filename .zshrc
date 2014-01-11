export CC=/usr/local/bin/gcc-4.2

# add zsh packages config path.
export PATH=$HOME/.rbenv/bin:$HOME/nodebrew/bin:/$HOME/bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH
export PGDATA=/usr/local/var/postgres
#rbenv setting
eval "$(rbenv init -)"

export RSENSE_HOME=/opt/rsense-0.3

if [[ -f ~/.nodebrew/nodebrew ]]; then
  export PATH=$HOME/.nodebrew/current/bin:$PATH:
  nodebrew use v0.10.12
fi


## zsh load
source /usr/local/share/zsh/site-functions
source $HOME/.rbenv/completions/rbenv.zsh

source ~/.zsh.d/zshrc


# add zsh plugins to use.
# load .zsh.d/plugins/*.zsh
plugins=(git git-flow git-extra gem osx ruby brew bundler node npm rails4 rails3 rake vi-mode )
bindkey -v

### alias
alias gst='git status'
alias ctg='ctags --langmap="Ruby:.rb" --exclude="*.js"  --exclude=".git*" -R .'
alias be='bundle exec'

