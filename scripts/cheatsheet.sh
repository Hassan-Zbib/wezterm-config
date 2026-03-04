#!/usr/bin/env bash
# WezTerm Cheat Sheet — Catppuccin Macchiato

# Colors
BLU='\e[38;2;138;173;244m'   # blue
GRN='\e[38;2;166;218;149m'   # green
YLW='\e[38;2;238;212;159m'   # yellow
PRP='\e[38;2;198;160;246m'   # purple
RED='\e[38;2;237;135;150m'   # red
CYN='\e[38;2;125;196;228m'   # sapphire
DIM='\e[38;2;110;115;141m'   # overlay
TXT='\e[38;2;202;211;245m'   # text
BLD='\e[1m'
RST='\e[0m'

COL_W=55  # width of each column
SEP="  ${DIM}│${RST}  "

header() { echo -e "${BLD}${CYN}  $1${RST}"; echo -e "${DIM}  $(printf '%.0s─' $(seq 1 $COL_W))${RST}"; }
row()    { printf "  ${BLD}${YLW}%-22s${RST}${TXT}%s${RST}\n" "$1" "$2"; }

# Build a section as an array of lines
# Usage: build_section "VARNAME" then add lines, call end_section
declare -a _SEC
start_section() { _SEC=(); }
sec_header()    { _SEC+=("$(header "$1")"); }
sec_row()       { _SEC+=("$(row "$1" "$2")"); }
sec_line()      { _SEC+=("$1"); }
sec_blank()     { _SEC+=(""); }

# Print two sections side by side
print_columns() {
   local -n left=$1
   local -n right=$2

   local left_len=${#left[@]}
   local right_len=${#right[@]}
   local max=$((left_len > right_len ? left_len : right_len))

   for ((i = 0; i < max; i++)); do
      local l="${left[$i]:-}"
      local r="${right[$i]:-}"
      # Strip ANSI codes to measure visible width
      local l_plain
      l_plain=$(echo -e "$l" | sed 's/\x1b\[[0-9;]*m//g')
      local l_len=${#l_plain}
      local pad=$((COL_W + 4 - l_len))
      if ((pad < 0)); then pad=0; fi
      printf "%b%*s${DIM}│${RST}  %b\n" "$l" "$pad" "" "$r"
   done
}

clear
echo
echo -e "  ${BLD}${BLU}██╗    ██╗███████╗███████╗████████╗███████╗██████╗ ███╗   ███╗${RST}"
echo -e "  ${BLD}${BLU}██║    ██║██╔════╝╚══███╔╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║${RST}"
echo -e "  ${BLD}${BLU}██║ █╗ ██║█████╗    ███╔╝    ██║   █████╗  ██████╔╝██╔████╔██║${RST}"
echo -e "  ${BLD}${BLU}██║███╗██║██╔══╝   ███╔╝     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║${RST}"
echo -e "  ${BLD}${BLU}╚███╔███╔╝███████╗███████╗   ██║   ███████╗██║  ██║██║ ╚═╝ ██║${RST}"
echo -e "  ${BLD}${BLU} ╚══╝╚══╝ ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝${RST}"
echo -e "\n  ${DIM}  Keyboard Shortcuts Cheat Sheet   •   Press Alt+w to close${RST}"
echo

# ── Row 1: Quick Actions  |  Tabs ────────────────────────────────────────────
start_section; sec_header "🎯 Quick Actions"
sec_row "F1"             "Cheat Sheet (this)"
sec_row "F2"             "Command Palette"
sec_row "F3"             "Launcher Menu"
sec_row "F4"             "Fuzzy Tabs"
sec_row "F5"             "Fuzzy Workspaces"
sec_row "F6"             "Toggle Notifications"
sec_row "F7"             "SSH Host Selector"
sec_row "F8"             "Copy Mode"
sec_row "F9"             "Save Session"
sec_row "F10"            "Restore Session"
sec_row "F11"            "Fullscreen"
sec_row "F12"            "Debug Overlay"
sec_row "Alt+f"          "Search"
sec_row "Alt+Ctrl+u"     "Open URL"
sec_row "Ctrl+Shift+C"   "Copy"
sec_row "Ctrl+Shift+V"   "Paste"
sec_row "Right-click"    "Copy / Paste"
sec_row "Alt+Shift+v"    "Paste image path"
COL_LEFT=("${_SEC[@]}")

start_section; sec_header "📑 Tabs"
sec_row "Alt+t"          "New Tab"
sec_row "Alt+Ctrl+t"     "New Tab (WSL)"
sec_row "Alt+["          "Previous Tab"
sec_row "Alt+]"          "Next Tab"
sec_row "Alt+Ctrl+["     "Move Tab Left"
sec_row "Alt+Ctrl+]"     "Move Tab Right"
sec_row "Alt+Ctrl+w"     "Close Tab"
sec_row "Alt+0"          "Rename Tab"
sec_row "Alt+Ctrl+0"     "Undo Rename"
sec_row "Alt+9"          "Toggle Tab Bar"
sec_blank
sec_header "✏️  Cursor Movement"
sec_row "Alt+←"          "Jump to Line Start"
sec_row "Alt+→"          "Jump to Line End"
sec_row "Shift+Enter"    "New line (no submit)"
sec_row "Alt+Backspace"  "Clear Line (Git Bash)"
COL_RIGHT=("${_SEC[@]}")

print_columns COL_LEFT COL_RIGHT
echo

# ── Row 2: Panes  |  Scrolling + Background ──────────────────────────────────
start_section; sec_header "🪟 Panes"
sec_row "Alt+\\"         "Split Vertical"
sec_row "Alt+Ctrl+\\"    "Split Horizontal"
sec_row "Alt+w"          "Close Pane"
sec_row "Alt+Enter"      "Zoom Pane"
sec_row "Alt+Ctrl+↑"     "Focus Up"
sec_row "Alt+Ctrl+↓"     "Focus Down"
sec_row "Alt+Ctrl+←"     "Focus Left"
sec_row "Alt+Ctrl+→"     "Focus Right"
sec_row "Alt+Ctrl+p"     "Swap Panes"
sec_blank
sec_header "🔤 Font & Window"
sec_row "Alt+="          "Grow Window"
sec_row "Alt+-"          "Shrink Window"
sec_row "Alt+n"          "New Window"
sec_row "Alt+Ctrl+Enter" "Maximize"
COL_LEFT=("${_SEC[@]}")

start_section; sec_header "📜 Scrolling"
sec_row "Alt+u"          "Scroll Up 5 lines"
sec_row "Alt+d"          "Scroll Down 5 lines"
sec_row "Page Up"        "Scroll Page Up"
sec_row "Page Down"      "Scroll Page Down"
sec_row "End"            "Scroll to Bottom"
sec_blank
sec_header "🖼️  Background Images"
sec_row "Alt+/"          "Random Image"
sec_row "Alt+,"          "Previous Image"
sec_row "Alt+."          "Next Image"
sec_row "Alt+Ctrl+/"     "Browse Images"
sec_row "Alt+b"          "Toggle Background"
COL_RIGHT=("${_SEC[@]}")

print_columns COL_LEFT COL_RIGHT
echo

# ── Row 3: Tools  |  Advanced Modes ──────────────────────────────────────────
start_section; sec_header "📁 File Manager (yazi)"
sec_row "Alt+e"          "Open yazi (auto-cd)"
sec_blank
sec_line "  ${DIM}hjkl navigate • Space select${RST}"
sec_line "  ${DIM}y copy • p paste • / search • q quit${RST}"
sec_blank
sec_header "🔀 Lazygit"
sec_row "lazygit"        "Open in current repo"
sec_row "lg"             "Alias for lazygit"
sec_blank
sec_header "📦 UniGetUI (Package Manager)"
sec_row "pkgs"           "Open UniGetUI"
sec_blank
sec_header "📄 Glow (Markdown Viewer)"
sec_row "glow FILE.md"   "Render markdown"
sec_row "glow"           "Browse md files (TUI)"
sec_blank
sec_header "📂 eza (Modern ls)"
sec_row "ls"             "List with icons"
sec_row "ll"             "List all (long)"
sec_row "lt"             "Tree view (2 levels)"
sec_blank
sec_header "📊 btop (System Monitor)"
sec_row "btop"           "Open system monitor"
COL_LEFT=("${_SEC[@]}")

start_section; sec_header "⚙️  Advanced Modes"
sec_line "  ${TXT}Leader Key: ${BLD}${YLW}Alt+Ctrl+Space${RST}${TXT}, then:${RST}"
sec_row "  f"            "Font Resize Mode"
sec_row "  p"            "Pane Resize Mode"
sec_blank
sec_line "  ${DIM}Font: ↑/↓ resize, r reset, Esc exit${RST}"
sec_line "  ${DIM}Pane: ↑/↓/←/→ resize, Esc exit${RST}"
sec_blank
sec_header "🔀 Lazygit Commands"
sec_row "Space"          "Stage/unstage file"
sec_row "c"              "Commit"
sec_row "P"              "Push"
sec_row "p"              "Pull"
sec_row "Enter"          "Expand file/view diff"
sec_row "[ / ]"          "Switch panels"
sec_row "/ (in panel)"   "Filter list"
sec_row "?"              "Keybindings help"
sec_row "x"              "Open actions menu"
sec_row "+"              "Next screen mode"
sec_row "s"              "Stash changes"
sec_row "S"              "View stash entries"
sec_row "n"              "New branch"
sec_row "r"              "Rebase options"
sec_row "M"              "Merge into current"
sec_row "z"              "Undo (via reflog)"
sec_row "q"              "Quit"
COL_RIGHT=("${_SEC[@]}")

print_columns COL_LEFT COL_RIGHT
echo

echo -e "  ${DIM}  Full docs: github.com/Hassan-Zbib/wezterm-config${RST}"
echo

# Keep open until user closes
read -n 1 -s -r -p $'\e[38;2;110;115;141m  Press any key to close...\e[0m'
echo
