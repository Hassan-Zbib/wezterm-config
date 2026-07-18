# ============================================================
# Git Bash Configuration — WezTerm Setup
# ============================================================
# Managed by dotbot — run ./install from the repo to symlink.
# ============================================================

# ---- WezTerm Shell Integration ----
# OSC 7: Tracks current directory so WezTerm tab title updates automatically
__urlencode() {
    local string="$1"
    local encoded=""
    local i char
    for ((i=0; i<${#string}; i++)); do
        char="${string:$i:1}"
        case "$char" in
            [a-zA-Z0-9.~_/-]) encoded+="$char" ;;
            *) printf -v hex '%02X' "'$char"; encoded+="%$hex" ;;
        esac
    done
    echo "$encoded"
}

__wezterm_set_cwd() {
    printf '\033]7;file://localhost%s\033\\' "$(__urlencode "$PWD")"
}

# OSC 133: Mark prompt boundaries for ScrollToPrompt (Shift+Up/Down)
__wezterm_prompt_mark() {
    printf '\033]133;A\033\\'
}

__wezterm_output_start() {
    printf '\033]133;C\033\\'
}

__wezterm_command_finished() {
    printf '\033]133;D;%s\033\\' "$?"
}

# ---- Skip heavy init when running inside Claude Code ----
if [[ -z "$CLAUDECODE" ]]; then
   # ---- Starship Prompt ----
   eval "$(starship init bash)"

   # ---- WezTerm Shell Integration ----
   # Skip under Warp: it runs its own prompt/Blocks integration, and the OSC
   # 7 / OSC 133 markers plus the Shift+Enter bind corrupt Warp's command
   # Blocks (BIND configs also trigger Warp's double-ENTER bug).
   if [[ "$TERM_PROGRAM" != "WarpTerminal" ]]; then
      # ---- Readline: Shift+Enter inserts newline (multi-line editing) ----
      [[ $- == *i* ]] && bind '"\e[13;2u": "\n"'

      # Append WezTerm integration after starship sets up PROMPT_COMMAND
      # OSC 133;D (command finished) + OSC 7 (cwd) + OSC 133;A (prompt start)
      PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__wezterm_command_finished; __wezterm_set_cwd; __wezterm_prompt_mark"

      # OSC 133;C: mark where command output begins (fires on every Enter)
      trap '__wezterm_output_start' DEBUG
   fi
fi

# ---- Yazi File Manager with Auto-cd ----
# Use 'yy' instead of 'yazi' to auto-cd when you quit
function yy() {
    local tmp
    tmp="$(mktemp)"
    yazi "$@" --cwd-file="$tmp"
    # WezTerm on Windows doesn't repaint the primary screen after a TUI app
    # leaves the alternate screen, so yazi's frame stays painted on exit.
    # Clear the screen + restore the cursor to redraw a clean prompt.
    [[ "$TERM_PROGRAM" == "WezTerm" ]] && printf '\033[2J\033[H\033[?25h'
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# ---- Claude Code Profile Switcher ----
# Runs the PowerShell switcher from git bash; args pass through to its params.
# e.g. ccp -List | ccp -Status | ccp -Profile MBV_Solutions | ccp (interactive)
function ccp() {
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File 'C:\Users\hassa\Desktop\GitHub\Claude-Switch\switch.ps1' "$@"
}

# ---- PATH ----
export PATH="$HOME/bin:$PATH"

# ---- Aliases ----
alias lg='lazygit'
alias lssh='lazyssh'
alias pkgs='"/c/Users/hassa/AppData/Local/Programs/UniGetUI/UniGetUI.exe" &'
alias ls='eza --icons --group-directories-first --git-repos --color-scale=all'
alias la='eza --icons --all --group-directories-first --git-repos --color-scale=all'
alias ll='eza --icons -l --all --git --git-repos --header --group-directories-first --color-scale=all'
alias lt='eza --icons --tree --level=2'
alias btop='btop4win'
alias cls='clear'
alias cc='claude --allow-dangerously-skip-permissions'
alias ff='fastfetch'

# ---- zoxide (smart cd) ----
# Warp manages PROMPT_COMMAND itself (its Blocks/prompt integration runs after
# this rc file) and drops zoxide's hook, tripping the doctor false-positive.
# zoxide still works; just silence the diagnostic under Warp.
[[ "$TERM_PROGRAM" == "WarpTerminal" ]] && export _ZO_DOCTOR=0
eval "$(zoxide init bash)"
