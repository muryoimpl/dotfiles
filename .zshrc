# export CC=/usr/local/bin/gcc-4.2

# add zsh packages config path.
# export PGDATA=/usr/local/var/postgres

### Added by the Heroku Toolbelt
# export PATH="/usr/local/heroku/bin:$PATH"
export TERMINAL=tilix

# for golang
export GOPATH=$HOME/go
export GOENV_ROOT="$HOME/.goenv"

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

export PATH=$GOENV_ROOT/shims:$GOENV_ROOT/bin:$HOME/.nodenv/bin:$HOME/.rbenv/bin:$GOPATH/bin:$HOME/local/bin:/usr/local/share/aclocal:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH

eval "$(rbenv init -)"
eval "$(nodenv init -)"
eval "$(goenv init -)"
eval "$(pyenv init -)"
eval "$(direnv hook zsh)"

export GOROOT=''

## zsh load
source /usr/share/zsh/site-functions
source ~/.goenv/completions/goenv.zsh

source $HOME/.zsh.d/zshrc
source $HOME/.zsh.d/pecos

# for zplug
source ~/ghq/github.com/zplug/zplug/init.zsh
zplug "sorin-ionescu/prezto"
zplug load --verbose

bindkey -v
stty stop undef

### alias
alias gst='git status'
alias gco='git checkout'
alias gdd='git diff'
alias gdc='git diff --cached'
alias gba='git branch -a'
alias gcm='git commit --verbose'
alias gad='git add'
alias gadd='git add'
alias gl='git log'
alias ctg='ctags --langmap="Ruby:.rb" --exclude="*.js"  --exclude=".git*" -R .'
alias be='bundle exec'
alias bundle='nocorrect bundle'
alias ghql='cd $(ghq list -p | peco)'
alias gb='git branch'
alias tmux='TERM=xterm-256color tmux'
alias gsed='sed'
alias syua='yay -Syu'
alias history-all='history -E 1'
alias hist='$(history -n 1 | peco)'
alias peco='TERM=xterm peco'
alias gbc='git checkout $(git branch | peco)'

 if [[ -f ~/local/work.zsh ]]; then
   source ~/local/work.zsh
 fi
