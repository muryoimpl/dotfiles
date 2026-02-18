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
alias syua='yay -Syuu && yay -Syua --debug'
alias history-all='history -E 1'
alias hist='$(history -n 1 | peco)'
alias peco='TERM=xterm peco'
alias gbc='git checkout $(git branch | peco)'
alias dc='docker-compose'
alias gsw='git switch $(git branch | peco)'
alias less='less -R'
alias sutra='cd $(find $SUTRA_DIR -mindepth 1 -maxdepth 1 -type d | peco)'
alias sshl='ssh $(grep -w Host ~/.ssh/config | awk "{print $2}" | peco)'
alias nvimdiff='nvim -d'
alias agl='ag -l'
alias la='eza -lbhgUma'
alias spf='spf -c ~/.config/superfile/config.toml'
alias presenterm='presenterm --config-file ~/.config/presenterm/config.yaml'
alias sfzf='fzf -e '
alias fzfp='fzf --preview "bat --color=always {} 2>/dev/null"'
alias devc='devcontainer'

if is_macos; then
  alias abrew='arch -arm64 brew'
  alias xbrew='arch -x86_64 brew'
  alias fos='foreman start'
  alias fclist='fc-list : family style'

  # export PATH="/opt/homebrew/opt/openssl@1.1/bin:$PATH"
  export PATH="/opt/homebrew/opt/openssl@3/bin:$PATH"
  export PATH="/opt/homebrew/opt/mysql@5.7/bin:$PATH"
  export PATH="/opt/homebrew/opt/imagemagick@6/bin:$PATH"
  export PATH="/Applications/MEGAcmd.app/Contents/MacOS:$PATH"
  export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
  export PATH="/opt/homebrew/opt/bison/bin:$PATH"
  export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
  export PATH="/opt/homebrew/opt/curl/bin:$PATH"

  export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib -L/opt/homebrew/opt/curl/lib -L/opt/homebrew/opt/postgresql@16/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/openssl@3/include -I/opt/homebrew/opt/postgresql@16/include -I/opt/homebrew/opt/curl/include"
  export RUBY_CONFIGURE_OPTS="--disable-shared --enable-yjit --disable-install-doc --disable-install-rdoc --with-libyaml-dir=$(brew --prefix libyaml) --with-openssl-dir=$(brew --prefix openssl@3) --with-readline-dir=$(brew --prefix readline)"

  alias zellij='zellij options --copy-command pbcopy'
elif is_linux; then
  alias fclist='fc-list : family style'
  alias fd='fd --hidden --ignore-case'
  alias rg='rg --hidden --no-ignore'
  alias cdmega='cd ~/local/MEGASync'
  alias zoom='QT_QPA_PLATFORM=xcb zoom'
  # export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"

  alias pc='podman-compose'
  alias zellij='zellij options --copy-command wl-copy'
  alias locals3='aws --endpoint-url=http://localhost:9090 --profile s3mock s3'
elif is_win; then
  alias ssh='ssh.exe'
  alias ssh-add='ssh-add.exe'
  alias ssh-addl='ssh-add.exe -l'
  alias op='op.exe'

  alias fclist='fc-list : family style'
  alias fd='fd --hidden --ignore-case'
  alias rg='rg --hidden --no-ignore'
  alias zellij='zellij options --copy-command xclip -selection clipboard'
  alias locals3='aws --endpoint-url=http://localhost:9090 --profile s3mock s3'
fi

# yazi shortcut function
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

_cdwt() {
  local dir
  dir=$(
    git-wt |
      fzf --header-lines=1 |
      awk '{if ($1 == "*") print $2; else print $1}'
  ) || return

  [[ -n "$dir" ]] && cd -- "$dir"
}
alias cdwt='_cdwt'
