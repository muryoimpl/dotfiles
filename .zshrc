# export CC=/usr/local/bin/gcc-4.2

# add zsh packages config path.
# export PGDATA=/usr/local/var/postgres

### Added by the Heroku Toolbelt
# export PATH="/usr/local/heroku/bin:$PATH"

# for golang
export GOPATH=$HOME/go
export GOENV_ROOT="$HOME/.goenv"

eval "$(rbenv init -)"
eval "$(nodenv init -)"
eval "$(goenv init -)"

eval "$(direnv hook zsh)"
# if [[ -f ~/.nodenv/bin/nodenv ]]; then
#   node_version=6.9.1
#   export NODENV_VERSION=${node_version}
#   echo "node version: $node_version"
# fi

export GOROOT=''

## zsh load
source /usr/share/zsh/site-functions
source ~/.goenv/completions/goenv.zsh

source $HOME/.zsh.d/zshrc
source $HOME/.zsh.d/pecos

# for zplug
source ~/.ghq/github.com/zplug/zplug/init.zsh
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

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /home/muryoimpl/work/esm/MCDP_related/stacc-updater/node_modules/tabtab/.completions/serverless.zsh ]] && . /home/muryoimpl/work/esm/MCDP_related/stacc-updater/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /home/muryoimpl/work/esm/MCDP_related/stacc-updater/node_modules/tabtab/.completions/sls.zsh ]] && . /home/muryoimpl/work/esm/MCDP_related/stacc-updater/node_modules/tabtab/.completions/sls.zsh
