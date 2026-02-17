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
