#!/bin/sh

# host
xhost +localhost
xhost +$HOST

# Xdefaults
if [ -e $HOME/.Xdefaults ] ; then
    xrdb ~/.Xdefaults
fi

# xmodmap
if [ -e $HOME/.xmodmaprc ] ; then
    xmodmap $HOME/.xmodmaprc
fi

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

#exec dbus-launch --exit-with-session startxfce4
exec dbus-launch --exit-with-session subtle 
