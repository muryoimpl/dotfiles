typeset -U path
path=(
      /bin(N-/)
      $HOME/local/bin(N-/)
      /opt/local/bin(N-/)
      /usr/local/bin(N-/)
      /usr/bin(N-/))

typeset -xT SUDO_PATH sudo_path
typeset -U sudo_path
sudo_path=({,/usr/local,/usr}/sbin(N-/))

typeset -U manpath
manpath=(# 自分用
         $HOME/local/share/man(N-/)
         /opt/local/share/man(N-/)
         /usr/local/share/man(N-/)
         /usr/share/man(N-/))

# see ~/.config/systemd/user/ssh-agent.service
# export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

if [ -n "$DESKTOP_SESSION" ];then
    eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
    export SSH_AUTH_SOCK
fi
