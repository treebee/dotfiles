
# Modules
autoload complist
autoload -U compinit
autoload edit-command-line
autoload -U colors
zle -N edit-command-line

# Completion
compinit
compdef -d hg # Disable slow completion for mercurial
compdef -d grep
compdef -d mplayer
compdef -d chmod
colors

# Options
setopt correct
setopt hist_ignore_all_dups
setopt autocd
setopt extended_glob
setopt extended_history
setopt append_history
setopt auto_resume
setopt auto_continue
setopt auto_pushd
setopt multios
setopt short_loops
setopt listpacked
setopt pushd_ignore_dups
setopt prompt_subst

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=5000

# Style
zstyle ':completion:*:descriptions' format '%U%B%d%b%u' 
zstyle ':completion:*:warnings' format '%BSorry, no matches for: %d%b' 

# Keys bindings
bindkey "^e" edit-command-line
bindkey "^f" forward-word
bindkey "^b" backward-word
bindkey "^t" transpose-chars
bindkey "^q" quote-line
bindkey "^k" kill-line
bindkey "^w" delete-word

bindkey "\e[1~" beginning-of-line
bindkey "\e[7~" beginning-of-line
bindkey "\e[8~" end-of-line
bindkey "\e[4~" end-of-line
bindkey "\e[3~" delete-char

# History search
bindkey "^R" history-incremental-search-backward

# Prompt
if [ "$USER" = "root" ] ; then
  PS1=%1~$'%{\e[36;1m%}%(1j.%%%j.)%{\e[30;1m%}> %{\e[0m%}'
else
  PS1=%1~$'%{\e[36;1m%}%(1j.%%%j.)%{\e[34;1m%}> %{\e[0m%}'
fi

umask 022

if [ -e $HOME/bin ] ; then
  export PATH=$HOME/bin:$PATH
fi

if [ -f /usr/bin/vim ] ; then
  export EDITOR=/usr/bin/vim
fi

# XDG dirs
export XDG_DESKTOP_DIR=$HOME/Desktop
export XDG_DOWNLOAD_DIR="$HOME/downloads"
#export XDG_TEMPLATES_DIR=$HOME
#export XDG_PUBLICSHARE_DIR=$HOME
export XDG_DOCUMENTS_DIR="$HOME/docs"
export XDG_MUSIC_DIR="$HOME/music"
export XDG_PICTURES_DIR="$HOME/pictures"
export XDG_VIDEOS_DIR="$HOME/videos"

# Browser
export BROWSER="/usr/bin/chromium"

# Update title
case $TERM in
  xterm*|urxvt*|screen*)
    chpwd() { print -Pn "\e]0;%n@%m: %~\a" }
    ;;
esac

# Aliases
if [ -f $HOME/.zshalias ] ; then
  source $HOME/.zshalias
fi

# Virtualenvwrapper
export WORKON_HOME=~/.virtualenvs
source /usr/bin/virtualenvwrapper.sh

if [ -n "$VIRTUAL_ENV" ]; then
  echo $VIRTUAL_ENV
  source "$VIRTUAL_ENV/bin/activate"
fi

export $(dbus-launch)
export LPDEST=mfc465

# extending PATH, LD_LIBRARY_PATH etc...
export PATH=/usr/local/cuda-5.5/bin:/root/.gem/ruby/1.9.1/bin:$PATH
export PATH=/opt/pycharm/bin:/home/patrick/.gem/ruby/2.0.0/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-5.5/lib64:/usr/local/cuda-5.5/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/opt/openmm/lib:/opt/openmm/lib/plugins:$LD_LIBRARY_PATH
export OPENMM_INCLUDE_PATH=/opt/openmm/include
export OPENMM_LIB_PATH=/opt/openmm/lib
export OPENMM_PLUGIN_DIR=/opt/openmm/lib/plugins
