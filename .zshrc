source ~/.zsh.d/zshrc

export CC=/usr/local/bin/gcc-4.2

# add zsh packages config path.
#source ~/.zsh.d/config/packages.zsh
export PATH=$HOME/node_modules/.bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin/:/usr/bin:/usr/sbin:/bin:/sbin:$PATH
#export PATH=$HOME/.rbenv/bin:$HOME/node_modules/.bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin:/usr/sbin/:/bin:/sbin:$PATH

#rbenv setting
#eval "$(rbenv init -)"
#source /Users/muryoimpl/.rbenv/completions/rbenv.zsh

#rvm setting
PATH=$PATH:$HOME/.rvm/bin 
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*




# add zsh plugins to use.
# load .zsh.d/plugins/*.zsh
plugins=(git gem osx ruby brew bundler node npm pow rails3 rake vi-mode)
bindkey -v

if [[ -f ~/.nodebrew/nodebrew ]]; then
  export PATH=$HOME/.nodebrew/current/bin:$PATH:
  nodebrew use v0.9.0
fi

alias gst='git status'
alias ctg='ctags --langmap=RUBY:.rb --exclude="*.js"  --exclude=".git*" -R .'
