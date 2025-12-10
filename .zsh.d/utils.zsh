OS_NAME="$(uname -r -o)"
DIST_NAME="$(cat /etc/issue)"

function is_linux() {
  [[ $OS_NAME =~ 'Linux' ]]
}

function is_macos() {
  [[ $OS_NAME =~ 'Darwin' ]]
}

function is_win() {
  [[ $OS_NAME =~ 'WSL2' ]]
}

function is_debian() {
  [[ $DIST_NAME =~ 'Debian' ]]
}
