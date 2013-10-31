
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
if [ -e /usr/bin/virtualenvwrapper.sh ] ; then
    source /usr/bin/virtualenvwrapper.sh
elif [ -e ~/bin/virtualenvwrapper.sh ] ; then
    source ~/bin/virtualenvwrapper.sh
fi

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

parse_git_branch() {
  ref=$(git symbolic-ref HEAD 2> /dev/null) || return
  echo "("${ref#refs/heads/}")"
}

# https://github.com/MrElendig/dotfiles-alice/blob/master/.zshrc
setprompt() {
  # load some modules
  setopt prompt_subst

  # make some aliases for the colours: (coud use normal escap.seq's too)
  for color in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
    eval PR_$color='%{$fg[${(L)color}]%}'
  done
  PR_NO_COLOR="%{$terminfo[sgr0]%}"

  # Check the UID
  if [[ $UID -ge 1000 ]]; then # normal user
    eval PR_USER='${PR_GREEN}%n${PR_NO_COLOR}'
    eval PR_USER_OP='${PR_GREEN}%#${PR_NO_COLOR}'
  elif [[ $UID -eq 0 ]]; then # root
    eval PR_USER='${PR_RED}%n${PR_NO_COLOR}'
    eval PR_USER_OP='${PR_RED}%#${PR_NO_COLOR}'
  fi

  # Check if we are on SSH or not
  if [[ -n "$SSH_CLIENT"  ||  -n "$SSH2_CLIENT" ]]; then 
    eval PR_HOST='${PR_RED}%M${PR_NO_COLOR}' #SSH
  else 
    eval PR_HOST='${PR_GREEN}%M${PR_NO_COLOR}' # no SSH
  fi
  # set the prompt
  git_branch=$(parse_git_branch)
  if [[ $git_branch != '' ]]; then
    PS1=$'${PR_CYAN}${PR_USER}${PR_CYAN} @ ${PR_HOST}${PR_CYAN} in ${PR_BLUE}%~${PR_CYAN} on $git_branch
${PR_USER_OP} '
  else
    PS1=$'${PR_CYAN}${PR_USER}${PR_CYAN} @ ${PR_HOST}${PR_CYAN} in ${PR_BLUE}%~${PR_CYAN}
${PR_USER_OP} '
  fi
  PS2=$'%_>'
  RPROMPT=$'${vcs_info_msg_0_}'
}
setprompt

# Enable auto-execution of functions.
typeset -ga preexec_functions
typeset -ga precmd_functions
typeset -ga chpwd_functions

chpwd_functions+='setprompt'
