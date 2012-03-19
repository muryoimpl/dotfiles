source ~/.zsh.d/zshrc

export CC=/usr/local/bin/gcc-4.2

PATH=$PATH:/usr/local/share/aclocal:
# add zsh packages config path.
#source ~/.zsh.d/config/packages.zsh

# add zsh plugins to use.
# load .zsh.d/plugins/*.zsh
plugins=(git gem osx ruby brew bundler node npm pow rails3 rake rvm vi-mode)
bindkey -v
