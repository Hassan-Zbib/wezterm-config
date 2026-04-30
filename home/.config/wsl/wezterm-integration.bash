# ============================================================
# WezTerm Shell Integration for WSL
# ============================================================
# Source this from your WSL ~/.bashrc:
#   [ -f /mnt/c/Users/hassa/.config/wsl/wezterm-integration.bash ] && \
#     source /mnt/c/Users/hassa/.config/wsl/wezterm-integration.bash
# ============================================================

# OSC 7: Report current directory so WezTerm tracks CWD inside WSL
__wezterm_set_cwd() {
    printf '\033]7;file://%s%s\033\\' "$(hostname)" "$PWD"
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

# Append to PROMPT_COMMAND (works alongside starship or any other prompt)
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__wezterm_command_finished; __wezterm_set_cwd; __wezterm_prompt_mark"

# OSC 133;C: mark where command output begins (fires on every Enter)
trap '__wezterm_output_start' DEBUG
