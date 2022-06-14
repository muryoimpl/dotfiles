OS_NAME="$(uname)"

function is_linux() {
  [[ $OS_NAME == 'Linux' ]]
}

function is_macos() {
  [[ $OS_NAME == 'Darwin' ]]
}
