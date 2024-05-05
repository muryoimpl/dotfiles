OS_NAME="$(uname -r -o)"

function is_linux() {
  [[ $OS_NAME =~ 'Linux' ]]
}

function is_macos() {
  [[ $OS_NAME =~ 'Darwin' ]]
}

function is_win() {
  [[ $OS_NAME =~ 'WSL2' ]]
}
