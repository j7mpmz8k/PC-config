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
    local target_dir="."
    local word_boundary=""

    # 1. Parse optional flags before the main arguments
    while [[ $1 == -* && ! $1 =~ ^-[0-9]+$ ]]; do
        case "$1" in
            -a|--all) 
                include_hidden=true
                shift
                ;;
            -c|--case-sensitive) 
                case_insensitive=""
                perl_flags="g"
                shift
                ;;
            -l|--list) 
                list_only="-l"
                shift
                ;;
            -w|--word)
                word_boundary="\b"
                shift
                ;;
            -d|--dir)
                target_dir="$2"
                shift 2
                ;;
            -e|--ext) 
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
        echo "Usage: supergrep [OPTIONS] <lines> <word1> [-exclude_word2] [+ word3] ..."
        echo ""
        echo "Options:"
        echo "  -a, --all         : Search all files, including hidden ones."
        echo "  -c, --case-sensitive: Perform a case-sensitive search."
        echo "  -w, --word        : Match whole words only."
        echo "  -l, --list        : Only list the names of files containing matches."
        echo "  -e, --ext <exts>  : Filter by file extension, comma-separated (e.g., py,md)."
        echo "  -d, --dir <path>  : Directory to search (defaults to current directory)."
        echo ""
        echo "Parameters:"
        echo "  <lines>           : Context lines to show (e.g., 5 or 0)."
        echo "  <words>           : Words to include."
        echo "  -                 : Prefix a word with '-' to EXCLUDE it (NOT)."
        echo "  +                 : Use '+' to create an OR group."
        echo ""
        echo "Examples:"
        echo "  supergrep -w -d /var/log 0 error database"
        echo "  supergrep -e py,js 2 error -database"
        echo "  supergrep 0 cherry + fig"
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
            groups+=("${current_group}.*")
            current_group=""
        elif [[ "$term" == -* ]]; then
            local ex_word="${term:1}"
            current_group="${current_group}(?!.*${word_boundary}${ex_word}${word_boundary})"
        else
            current_group="${current_group}(?=.*${word_boundary}${term}${word_boundary})"
            if [ -n "$highlight_words" ]; then
                highlight_words="$highlight_words|"
            fi
            highlight_words="$highlight_words$term"
        fi
    done
    
    groups+=("${current_group}.*")

    local joined_groups=""
    for i in "${!groups[@]}"; do
        if [ "$i" -gt 0 ]; then
            joined_groups+="|"
        fi
        joined_groups+="${groups[$i]}"
    done
    
    local pattern="^${case_insensitive}(?:${joined_groups})$"

    # 3. Build and run the search command
    local grep_cmd="grep -n $list_only -C \"$lines\" -r -P"
    
    if [ "$include_hidden" = false ]; then
        # Exclude hidden folders AND common junk build folders
        grep_cmd="$grep_cmd --exclude-dir=\".[!.]*\" --exclude-dir=\"..?*\" --exclude-dir=\"node_modules\" --exclude-dir=\"target\" --exclude-dir=\"build\" --exclude-dir=\"dist\" --exclude-dir=\"__pycache__\" --exclude-dir=\"venv\""
        
        if [ "$has_ext_filter" = false ]; then
            grep_cmd="$grep_cmd --exclude=\".[!.]*\" --exclude=\"..?*\""
        fi
    fi

    # 4. Execute the dynamically built command
    if [ -n "$list_only" ] || [ ! -t 1 ] || [ -z "$highlight_words" ]; then
        eval "$grep_cmd --color=auto $file_filter \"\$pattern\" \"\$target_dir\""
    else
        export HIGHLIGHT_WORDS="$highlight_words"
        export PERL_FLAGS="$perl_flags"
        eval "GREP_COLORS='mt=' $grep_cmd --color=always $file_filter \"\$pattern\" \"\$target_dir\"" | perl -pe '
            my $hw = $ENV{HIGHLIGHT_WORDS};
            my $flags = $ENV{PERL_FLAGS};
            
            # Print separator cleanly
            if ($_ eq "--\n" || $_ eq "\e[36m\e[K--\e[m\e[K\n") {
                next;
            }
            
            # Grouped formatting logic
            if ( m/^(\e\[35m\e\[K(.*?)\e\[m\e\[K)(\e\[36m\e\[K([:\-])\e\[m\e\[K)(\e\[32m\e\[K(.*?)\e\[m\e\[K)(\e\[36m\e\[K([:\-])\e\[m\e\[K)(.*)$/s ) {
                my $file_color = $1;
                my $file_raw = $2;
                my $sep1_color = $3;
                my $line_color = $5;
                my $sep2_color = $7;
                my $content = $9;
                
                # Apply word highlights
                if ($flags eq "gi") {
                    $content =~ s/($hw)/\e[01;31m$1\e[m/gi;
                } else {
                    $content =~ s/($hw)/\e[01;31m$1\e[m/g;
                }
                
                my $out = "";
                if ($file_raw ne $last_file) {
                    if ($last_file ne "") {
                        $out .= "\n"; # Space between files
                    }
                    $out .= $file_color . "\n"; # Print file name once
                    $last_file = $file_raw;
                }
                
                # Print just the line number and matched text beneath the file
                $out .= "  " . $line_color . $sep2_color . " " . $content;
                $_ = $out;
            }
        '
    fi
}
