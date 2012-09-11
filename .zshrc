source ~/.zsh.d/zshrc

export CC=/usr/local/bin/gcc-4.2

# add zsh packages config path.
#source ~/.zsh.d/config/packages.zsh
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
export PATH=$HOME/.rbenv/bin:$HOME/.rbenv/shims:$HOME/.nodebrew/current/bin:$HOME/node_modules/.bin:$PATH:/usr/local/share/aclocal:

#rbenv setting
eval "$(rbenv init -)"
source /Users/muryoimpl/.rbenv/completions/rbenv.zsh

# add zsh plugins to use.
# load .zsh.d/plugins/*.zsh
plugins=(git gem osx ruby brew bundler node npm pow rails3 rake vi-mode)
bindkey -v

if [[ -f ~/.nodebrew/nodebrew ]]; then
  export PATH=$HOME/.nodebrew/current/bin:$PATH:
  nodebrew use v0.9.0
fi
