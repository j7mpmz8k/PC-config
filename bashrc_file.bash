# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
#alias ll='ls -l'
#alias la='ls -A'
#alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

[[ -n "$_TUTR" ]] && source $_TUTR || true  # shell tutorial shim DO NOT MODIFY

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
eval "$(pyenv virtualenv-init -)"


alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
#alias glow='glow -p' #run / to search via regular expression
#alias glow='glow -tl' #shows numbers

PS1="\V \[\e[1;32m\]\u\[\e[0m\]@\[\e[1;31m\]\h\[\e[0m\] \w \$ " #A colorful prompt that shows your username, hostname, and current directory

repl() {
#A utility function to easily reload Python scripts in the REPL (useful for development)
    if (( $# == 0 )); then
        1>&2 echo "Load a Python script into the REPL"
        1>&2 echo "Run exit() to restart the REPL, exit(1) to quit to the shell"
        1>&2 echo "    Usage: repl SCRIPT.py"
        return 1
    elif [[ ! -e $1 ]]; then
        1>&2 echo "File '$1' does not exist"
        1>&2 echo "    Usage: repl SCRIPT.py"
        return 1
    fi

    while python -i $1; do
        echo "run exit() to restart, exit(1) to quit"
        sleep .4
    done
}
. "$HOME/.cargo/env"



#mdview() {
#    # 1. Passthrough: If using -v/--verbose or no args, run the binary directly
#    if [[ "$@" == *"-v"* ]] || [[ -z "$1" ]]; then
#        command mdview "$@"
#        return
#    fi

#    # 2. Launcher Mode:
#    # Start the GUI in background (silencing output)
#    command mdview "$1" > /dev/null 2>&1 &
#    local GUI_PID=$!

#    # Open the editor in foreground
#    nano "$1"

#    # Cleanup: Kill the GUI when editor closes
#    kill $GUI_PID 2>/dev/null
#}

shortcuts() { # DO NOT MODIFY. SHORTCUTS COMMAND ADDED BY SHELL TUTOR
cat <<-:
[1;36mShortcut[0m | [1;36mAction[0m
---------|----------------------------------------------
  [0;35mUp[0m     | Bring up older commands from history
  [0;35mDown[0m   | Bring up newer commands from history
  [0;35mLeft[0m   | Move cursor BACKWARD one character
  [0;35mRight[0m  | Move cursor FORWARD one character
[0;35mBackspace[0m| Erase the character to the LEFT of the cursor
  [0;35mDelete[0m | Erase the character to the RIGHT of the cursor
  [0;35m^A[0m     | Move cursor to START of line
  [0;35m^E[0m     | Move cursor to END of line
  [0;35mM-B[0m    | Move cursor BACKWARD one whole word
  [0;35mM-F[0m    | Move cursor FORWARD one whole word
  [0;35m^C[0m     | Cancel (terminate) the currently running process
  [0;35mTab[0m    | Complete the command or filename at cursor
  [0;35m^W[0m     | Kill (cut) BACKWARD from cursor to beginning of word
  [0;35m^K[0m     | Kill FORWARD from cursor to end of line (kill)
  [0;35m^Y[0m     | Yank (paste) text to the RIGHT of the cursor
  [0;35m^L[0m     | Clear the screen while preserving command line
  [0;35m^U[0m     | Kill the entire command line
:
}

# Launch VS Code via Flatpak
alias code="flatpak run com.visualstudio.code"

# Map Alt+Left to Start of Line (same as Ctrl+A)
bind '"\e[1;3D": beginning-of-line'
# Map Alt+Right to End of Line (same as Ctrl+E)
bind '"\e[1;3C": end-of-line'
