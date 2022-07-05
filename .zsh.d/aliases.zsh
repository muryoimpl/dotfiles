### var
SUTRA_DIR=$HOME/local/MEGAsync/sutras-copying/

### alias
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"
alias g='git'
alias ctags='ctags --exclude="@${HOME}/.ctagsignore"'
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
alias syua='paru --skipreview -Syu'
alias history-all='history -E 1'
alias hist='$(history -n 1 | peco)'
alias peco='TERM=xterm peco'
alias gbc='git checkout $(git branch | peco)'
alias dc='docker-compose'
alias gsw='git switch $(git branch | peco)'
alias less='less -R'
alias sutra='cd $(find $SUTRA_DIR -mindepth 1 -maxdepth 1 -type d | peco)'

if is_macos; then
  alias abrew='arch -arm64 brew'
  alias xbrew='arch -x86_64 brew'
  alias fos='foreman start'
  alias fclist='fc-list : family style'
  alias la='exa -alhF'

  export PATH="/opt/homebrew/opt/openssl@1.1/bin:$PATH"
  export PATH="/opt/homebrew/opt/mysql@5.7/bin:$PATH"
  export PATH="/opt/homebrew/opt/imagemagick@6/bin:$PATH"

  export LDFLAGS="-L/opt/homebrew/opt/openssl@1.1/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/openssl@1.1/include"
  export RUBY_CONFIGURE_OPTS="--disable-shared --with-openssl-dir=$(brew --prefix openssl@1.1) --with-readline-dir=$(brew --prefix readline)"

elif is_linux; then
  alias fclist='fc-list : family style'
  alias la='exa -alhF'
  alias fd='fd --hidden --ignore-case'
  alias rg='rg --hidden --no-ignore'
  alias cdmega='cd ~/local/MEGASync'
fi

