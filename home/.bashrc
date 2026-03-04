# ============================================================
# Git Bash Configuration — WezTerm Setup
# ============================================================
#
# SETUP: Change the line below to match where you cloned the repo.
WEZTERM_CONFIG_DIR="$HOME/Desktop/GitHub/wezterm-config"
# ============================================================

# ---- WezTerm Shell Integration ----
# Tracks current directory so WezTerm tab title updates automatically
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

# ---- Skip heavy init when running inside Claude Code ----
if [[ -z "$CLAUDECODE" ]]; then
   # ---- System Info Panel (WezTerm only, shown once at shell startup) ----
   [[ -n "$WEZTERM_PANE" ]] && "$WEZTERM_CONFIG_DIR/scripts/sysinfo.sh"

   # ---- Readline: Shift+Enter inserts newline (multi-line editing) ----
   bind '"\e[13;2u": "\n"'

   # ---- Starship Prompt ----
   export STARSHIP_CONFIG="$WEZTERM_CONFIG_DIR/starship.toml"
   eval "$(starship init bash)"

   # Append WezTerm cwd tracking after starship sets up PROMPT_COMMAND
   PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__wezterm_set_cwd"
fi

# ---- Yazi File Manager with Auto-cd ----
# Use 'yy' instead of 'yazi' to auto-cd when you quit
function yy() {
    local tmp
    tmp="$(mktemp)"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# ---- Aliases ----
alias lg='lazygit'
alias pkgs='"/c/Users/Hasan/AppData/Local/Programs/UniGetUI/UniGetUI.exe" &'
alias ls='eza --icons'
alias ll='eza --icons -la'
alias lt='eza --icons --tree --level=2'
alias btop='btop4win'
