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

supergrep() {
    local include_hidden=false
    local case_insensitive="(?i)" # Case-insensitive by default
    local perl_flags="gi"
    local list_only=""
    local file_filter=""
    local has_ext_filter=false

    # 1. Parse optional flags before the main arguments
    while [[ $1 == -* && ! $1 =~ ^-[0-9]+$ ]]; do
        case "$1" in
            -a|--all) # Search all files (including hidden)
                include_hidden=true
                shift
                ;;
            -c|--case-sensitive) # Make the search case-sensitive
                case_insensitive=""
                perl_flags="g"
                shift
                ;;
            -l|--list) # List files only
                list_only="-l"
                shift
                ;;
            -e|--ext) # Filter by extension
                has_ext_filter=true
                IFS=',' read -ra EXTS <<< "$2"
                for ext in "${EXTS[@]}"; do
                    file_filter="$file_filter --include=*.$ext"
                done
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # Check if the user provided at least a number and one word
    if [ "$#" -lt 2 ]; then
        echo "Usage: supergrep [-a] [-c] [-l] [-e ext1,ext2] <lines> <word1> [-exclude_word2] [+ word3] ..."
        echo ""
        echo "Options:"
        echo "  -a, --all         : Search all files, including hidden ones."
        echo "  -c, --case-sensitive: Perform a case-sensitive search (case-insensitive by default)."
        echo "  -l, --list        : Only list the names of files containing matches."
        echo "  -e, --ext <exts>  : Filter by file extension, comma-separated (e.g., py,md)."
        echo ""
        echo "Parameters:"
        echo "  <lines>           : Context lines to show (e.g., 5 or 0)."
        echo "  <words>           : Words to include."
        echo "  -                 : Prefix a word with '-' to EXCLUDE it (NOT)."
        echo "  +                 : Use '+' to create an OR group."
        echo ""
        echo "Examples:"
        echo "  supergrep -l 0 error database            # List files with 'error' AND 'database'"
        echo "  supergrep -e py,js 2 error -database     # Search .py/.js for 'error' BUT NOT 'database'"
        echo "  supergrep 0 cherry + fig                 # Find 'cherry' OR 'fig'"
        echo "  supergrep 0 error + warn alert           # Find 'error' OR ('warn' AND 'alert')"
        return 1
    fi

    local lines="$1"
    shift 

    # 2. Build the Regex Pattern Dynamically
    local groups=()
    local current_group=""
    local highlight_words=""

    for term in "$@"; do
        if [[ "$term" == "+" || "$term" == "OR" ]]; then
            # Close the current AND group
            groups+=("${current_group}.*")
            current_group=""
        elif [[ "$term" == -* ]]; then
            # If the term starts with a hyphen, it's an EXCLUSION (NOT)
            local ex_word="${term:1}"
            current_group="${current_group}(?!.*${ex_word})"
        else
            # Otherwise, it's an INCLUSION (AND)
            current_group="${current_group}(?=.*${term})"
            # Build an OR-separated string of words to highlight later
            if [ -n "$highlight_words" ]; then
                highlight_words="$highlight_words|"
            fi
            highlight_words="$highlight_words$term"
        fi
    done
    
    # Add the final group after the loop finishes
    groups+=("${current_group}.*")

    # Join all the groups together with the Regex OR operator (|)
    local joined_groups=""
    for i in "${!groups[@]}"; do
        if [ "$i" -gt 0 ]; then
            joined_groups+="|"
        fi
        joined_groups+="${groups[$i]}"
    done
    
    # Wrap it all in a non-capturing group anchored to the start of the line
    local pattern="^${case_insensitive}(?:${joined_groups})$"

    # 3. Build and run the search command
    local grep_cmd="grep -n $list_only -C \"$lines\" -r -P"
    
    if [ "$include_hidden" = false ]; then
        # Always exclude hidden directories
        grep_cmd="$grep_cmd --exclude-dir=\".[!.]*\" --exclude-dir=\"..?*\""
        
        # Only exclude hidden files if no explicit --include filter is provided
        # (Using both --exclude and --include on files causes grep to ignore --include)
        if [ "$has_ext_filter" = false ]; then
            grep_cmd="$grep_cmd --exclude=\".[!.]*\" --exclude=\"..?*\""
        fi
    fi

    # 4. Execute the dynamically built command
    # If listing files, outputting to a pipe/file, or no words to highlight, run normally
    if [ -n "$list_only" ] || [ ! -t 1 ] || [ -z "$highlight_words" ]; then
        eval "$grep_cmd --color=auto $file_filter \"\$pattern\" ."
    else
        # If outputting to terminal, use a robust perl script to highlight ONLY 
        # the targeted keywords within the file content (ignoring file paths and line numbers).
        export HIGHLIGHT_WORDS="$highlight_words"
        export PERL_FLAGS="$perl_flags"
        eval "GREP_COLORS='mt=' $grep_cmd --color=always $file_filter \"\$pattern\" ." | perl -pe '
            my $hw = $ENV{HIGHLIGHT_WORDS};
            my $flags = $ENV{PERL_FLAGS};
            # Match the grep header: {file}:{line}: or {file}-{line}-
            if ( s/^((?:.*?\e\[36m\e\[K[:\-]\e\[m\e\[K){2})// ) {
                my $header = $1;
                my $content = $_;
                if ($flags eq "gi") {
                    $content =~ s/($hw)/\e[01;31m$1\e[m/gi;
                } else {
                    $content =~ s/($hw)/\e[01;31m$1\e[m/g;
                }
                $_ = $header . $content;
            }
        '
    fi
}
