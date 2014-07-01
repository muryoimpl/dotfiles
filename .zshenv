source ~/.zsh.d/zshenv

export GOPATH=$HOME/gocode

#export DYLD_LIBRARY_PATH=/usr/local/opt/cairo/lib
export PATH=$HOME/.rbenv/bin:$HOME/nodebrew/bin:$HOME/bin:$GOPATH/bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH

eval "$(rbenv init -)"
