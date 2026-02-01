#!/usr/bin/env bash

# Taken from https://patrickmccanna.net/a-detailed-writeup-of-claude-code-constrained-by-bubblewrap/
# and adapted as needed

ARGS=("${@:2}")


# Optional paths - only bind if they exist
OPTIONAL_BINDS=""

if [[ "$AGENT_CMD" == "cursor" || "$AGENT_CMD" == "cursor-agent" || "$AGENT_CMD" == "agent" ]]; then
    AGENT="cursor"
    [ -d "$HOME/.local/share/cursor-agent" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind $HOME/.local/share/cursor-agent $HOME/.local/share/cursor-agent"
    [ -d "$HOME/.config/Cursor" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind $HOME/.config/Cursor $HOME/.config/Cursor"
    [ -d "/opt/cursor-agent" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind /opt/cursor-agent /opt/cursor-agent"
    [ -d "/usr/share/cursor" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind /usr/share/cursor /usr/share/cursor"
    [ -d "/sys" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind /sys /sys"
    [ -d "/run/dbus" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind /run/dbus /run/dbus"
    OPTIONAL_BINDS="$OPTIONAL_BINDS --bind $XDG_RUNTIME_DIR $XDG_RUNTIME_DIR"
else
    AGENT="$1"
fi

[ -d "$HOME/.nvm" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --ro-bind $HOME/.nvm $HOME/.nvm"
[ -d "$HOME/.config/agents" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --ro-bind $HOME/.config/agents $HOME/.config/agents"
[ -d "$HOME/.config/$AGENT" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind $HOME/.config/$AGENT $HOME/.config/$AGENT"
[ -d "$HOME/.local/share/$AGENT" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind $HOME/.local/share/$AGENT $HOME/.local/share/$AGENT"
[ -d "$HOME/.$AGENT" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind $HOME/.$AGENT $HOME/.$AGENT"
[ -d "$HOME/.npm" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/.config/git" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --ro-bind $HOME/.config/git $HOME/.config/git"

bwrap \
  --ro-bind /usr /usr \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --ro-bind /bin /bin \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --ro-bind /etc/hosts /etc/hosts \
  --ro-bind /etc/ssl /etc/ssl \
  --ro-bind /etc/passwd /etc/passwd \
  --ro-bind /etc/group /etc/group \
  --ro-bind "$HOME/.gitconfig" "$HOME/.gitconfig" \
  --ro-bind "$HOME/.local" "$HOME/.local" \
  $OPTIONAL_BINDS \
  --bind "$HOME/.cache" "$HOME/.cache" \
  --bind "$PWD" "$PWD" \
  --tmpfs /tmp \
  --proc /proc \
  --dev /dev \
  --setenv HOME "$HOME" \
  --setenv USER "$USER" \
  --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" \
  --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
  --setenv MOZ_ENABLE_WAYLAND 1 \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --chdir "$PWD" \
  "$(which $1)" "${ARGS[@]}"
