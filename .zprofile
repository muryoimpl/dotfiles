# see ~/.config/systemd/user/ssh-agent.service
# enable command: `systemctl --user enable ssh-agent.service`
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

eval `ssh-agent`
export GPG_TTY=$(tty)
