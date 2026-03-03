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

header() { echo -e "\n${BLD}${CYN}  $1${RST}"; echo -e "${DIM}  $(printf '%.0s─' {1..55})${RST}"; }
row()    { printf "  ${BLD}${YLW}%-30s${RST}${TXT}%s${RST}\n" "$1" "$2"; }
row2()   { printf "  ${BLD}${YLW}%-30s${RST}${TXT}%-26s${RST}  ${BLD}${YLW}%-26s${RST}${TXT}%s${RST}\n" "$1" "$2" "$3" "$4"; }

clear
echo
echo -e "  ${BLD}${BLU}██╗    ██╗███████╗███████╗████████╗███████╗██████╗ ███╗   ███╗${RST}"
echo -e "  ${BLD}${BLU}██║    ██║██╔════╝╚══███╔╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║${RST}"
echo -e "  ${BLD}${BLU}██║ █╗ ██║█████╗    ███╔╝    ██║   █████╗  ██████╔╝██╔████╔██║${RST}"
echo -e "  ${BLD}${BLU}██║███╗██║██╔══╝   ███╔╝     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║${RST}"
echo -e "  ${BLD}${BLU}╚███╔███╔╝███████╗███████╗   ██║   ███████╗██║  ██║██║ ╚═╝ ██║${RST}"
echo -e "  ${BLD}${BLU} ╚══╝╚══╝ ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝${RST}"
echo -e "\n  ${DIM}  Keyboard Shortcuts Cheat Sheet   •   Press Alt+w to close${RST}"

header "🎯 Quick Actions"
row2 "F1"          "Cheat Sheet (this)" "F11"             "Fullscreen"
row2 "F2"          "Command Palette"    "F12"              "Debug Overlay"
row2 "F3"          "Launcher Menu"      "F6"               "Toggle Notifications"
row2 "F4"          "Fuzzy Tabs"         "F7"               "SSH Host Selector"
row2 "F8"          "Copy Mode"          "F9"               "Save Session"
row2 "F10"         "Restore Session"    "F5"               "Fuzzy Workspaces"
row2 "Alt+f"       "Search"             "Alt+Ctrl+u"       "Open URL"
row2 "Ctrl+Shift+C" "Copy"             "Ctrl+Shift+V"     "Paste"
row2 "Right-click" "Copy / Paste"      "Alt+Shift+v"      "Paste image path"

header "✏️  Cursor Movement"
row2 "Alt+←"       "Jump to Line Start" "Alt+→"           "Jump to Line End"
row2 "Shift+Enter"  "New line (no submit)" "Alt+Backspace"  "Clear Line (Git Bash only)"

header "📑 Tabs"
row2 "Alt+t"       "New Tab"            "Alt+["            "Previous Tab"
row2 "Alt+Ctrl+t"  "New Tab (WSL)"      "Alt+]"            "Next Tab"
row2 "Alt+Ctrl+w"  "Close Tab"          "Alt+Ctrl+["       "Move Tab Left"
row2 "Alt+0"       "Rename Tab"         "Alt+Ctrl+]"       "Move Tab Right"
row2 "Alt+Ctrl+0"  "Undo Rename"        "Alt+9"            "Toggle Tab Bar"

header "🪟 Panes"
row2 "Alt+\\"      "Split Vertical"     "Alt+Ctrl+↑"       "Focus Up"
row2 "Alt+Ctrl+\\" "Split Horizontal"   "Alt+Ctrl+↓"       "Focus Down"
row2 "Alt+w"       "Close Pane"         "Alt+Ctrl+←"       "Focus Left"
row2 "Alt+Enter"   "Zoom Pane"          "Alt+Ctrl+→"       "Focus Right"
row  "Alt+Ctrl+p"  "Swap Panes"

header "📜 Scrolling"
row2 "Alt+u"       "Scroll Up 5 lines"  "Alt+d"            "Scroll Down 5 lines"
row2 "Page Up"     "Scroll Page Up"     "Page Down"        "Scroll Page Down"
row  "End"         "Scroll to Bottom"

header "🖼️  Background Images"
row2 "Alt+/"       "Random Image"       "Alt+,"            "Previous Image"
row2 "Alt+Ctrl+/"  "Browse Images"      "Alt+."            "Next Image"
row  "Alt+b"       "Toggle Background On/Off"

header "🔤 Font & Window"
row2 "Alt+="       "Grow Window"        "Alt+n"            "New Window"
row2 "Alt+-"       "Shrink Window"      "Alt+Ctrl+Enter"   "Maximize"

header "📁 File Manager (yazi)"
row2 "Alt+e"       "Open yazi (auto-cd on quit)" ""        ""
echo -e "\n  ${DIM}  Inside yazi: hjkl navigate • Space select • y copy • p paste • / search • q quit${RST}"

header "⚙️  Advanced Modes"
echo -e "  ${TXT}Leader Key: ${BLD}${YLW}Alt+Ctrl+Space${RST}${TXT}, then:${RST}"
row  "  f"         "→ Font Resize Mode (k/j resize, r reset, Esc exit)"
row  "  p"         "→ Pane Resize Mode (h/j/k/l resize, Esc exit)"

echo
echo -e "  ${DIM}  Full docs: github.com/Hassan-Zbib/wezterm-config${RST}"
echo

# Keep open until user closes
read -n 1 -s -r -p $'\e[38;2;110;115;141m  Press any key to close...\e[0m'
echo
