# export CC=/usr/local/bin/gcc-4.2

# add zsh packages config path.
# export PGDATA=/usr/local/var/postgres

### Added by the Heroku Toolbelt
# export PATH="/usr/local/heroku/bin:$PATH"
export TERMINAL=alacritty
export PAGER='less'
export EDITOR='vim'

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

bindkey -v
stty stop undef

# mkdir -p ~/local/lib/completion
# curl -o ~/local/lib/completion/git-completion.bash https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash
# curl -o ~/local/lib/completion/_git https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.zsh
# echo "# Load completion files from the ~/.zsh directory." >> ~/.zshrc
# echo "zstyle ':completion:*:*:git:*' script ~/local/lib/completion/git-completion.bash" >> ~/.zshrc
# echo 'fpath=(~/.zsh $fpath)' >> ~/.zshrc
# echo "autoload -Uz compinit && compinit" >> ~/.zshrc
# Load completion files from the ~/.zsh directory.
zstyle ':completion:*:*:git:*' script ~/local/lib/completion/git-completion.bash
fpath=(~/local/lib/completion $fpath)
autoload -Uz compinit && compinit

# setup zplugin.zsh
source ~/.zinit/bin/zinit.zsh
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

############################################
# zsh plugins
############################################
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma/fast-syntax-highlighting
zinit load zsh-users/zsh-completions

export FZF_DEFAULT_OPTS='--no-height --no-reverse'
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
zinit ice from"gh-r" as"program"
zinit load junegunn/fzf-bin

export FZF_TMUX=1
zinit ice as:command pick"bin/fzf-tmux" multisrc"shell/key-bindings.zsh shell/completion.zsh"
zinit light "junegunn/fzf"

zinit ice as"completion"
zinit snippet https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker

zinit light "chrissicool/zsh-256color"

zinit ice as:command src"manydots-magic"
zinit light "knu/zsh-manydots-magic"

### alias
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"
alias la='ls -lhAF --color=auto'
alias g='git'
alias ctags='ctags -f .tags'
alias gst='git status'
alias gco='git checkout'
alias gdd='git diff'
alias gdc='git diff --cached'
alias gba='git branch -a'
alias gcm='git commit --verbose'
alias gad='git add'
alias gadd='git add'
alias gl='git log'
alias be='bundle exec'
alias bundle='nocorrect bundle'
alias ghql='cd $(ghq list -p | peco)'
alias gb='git branch'
alias gsed='sed'
alias syua='yay -Syu'
alias history-all='history -E 1'
alias hist='$(history -n 1 | peco)'
alias peco='TERM=xterm peco'
alias gbc='git checkout $(git branch | peco)'
alias dc='docker-compose'
alias gsw='git switch $(git branch | peco)'
alias fclist='fc-list : family style'

if [[ -f ~/local/work.zsh ]]; then
  source ~/local/work.zsh
else
  # for rootless docker
  export PATH=/home/muryoimpl/bin:$PATH
  export DOCKER_HOST=unix:///run/user/1000/docker.sock
fi

neofetch
