#!/usr/bin/env python
"""WezTerm Cheat Sheet — Catppuccin Macchiato"""

import re
import sys
import time
import shutil
import unicodedata

# ── Colors ────────────────────────────────────────────────────────────────────
BLU = '\033[38;2;138;173;244m'
YLW = '\033[38;2;238;212;159m'
CYN = '\033[38;2;125;196;228m'
DIM = '\033[38;2;110;115;141m'
TXT = '\033[38;2;202;211;245m'
BLD = '\033[1m'
RST = '\033[0m'

COL_W    = 46
ANSI     = re.compile(r'\x1b\[[0-9;]*m')
_SLOT_W  = COL_W + 7           # width of one column slot (content + sep + gaps)
_TERM_W  = shutil.get_terminal_size((160, 40)).columns
NUM_COLS = 4 if _TERM_W >= 4 * _SLOT_W - 3 else 3   # 4 cols needs ≥209 chars

def wlen(s):
    """Exact terminal display width — handles emoji, wide chars, and FE0F variation selectors."""
    plain = ANSI.sub('', s)
    w = 0
    chars = list(plain)
    i = 0
    while i < len(chars):
        cp = ord(chars[i])
        # zero-width codepoints: skip entirely
        if cp in (0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0xFE0E, 0xFEFF, 0xFE0F):
            i += 1
            continue
        ew = unicodedata.east_asian_width(chars[i])
        # FE0F (emoji variation selector) after this char?
        next_vs16 = i + 1 < len(chars) and ord(chars[i + 1]) == 0xFE0F
        if ew in ('W', 'F'):
            w += 2
            i += 2 if next_vs16 else 1  # skip redundant FE0F if present
        elif next_vs16:
            w += 2   # narrow char made emoji-wide by FE0F (e.g. ✏️ ⚙️)
            i += 2
        else:
            w += 1
            i += 1
    return w

# ── Builders ──────────────────────────────────────────────────────────────────
def header(title):
    return [
        f'{BLD}{CYN}  {title}{RST}',
        f'{DIM}  {"─" * COL_W}{RST}',
    ]

def row(key, desc):
    pad = max(22 - wlen(key), 0)
    return [f'  {BLD}{YLW}{key}{RST}{" " * pad}{TXT}{desc}{RST}']

def blank():
    return ['']

def note(text):
    return [f'  {DIM}{text}{RST}']

def dim(text):
    return [text]

def render_cols(*cols):
    """Render N columns side by side. Works for any number of columns."""
    n    = max((len(c) for c in cols), default=0)
    sep  = f'{DIM}│{RST}'
    seps = [COL_W + 5 + i * _SLOT_W for i in range(len(cols) - 1)]
    for i in range(n):
        parts = [cols[j][i] if i < len(cols[j]) else '' for j in range(len(cols))]
        line  = parts[0]
        for j, sp in enumerate(seps):
            line += f'\033[{sp}G{sep}  {parts[j + 1]}'
        print(line)

# ── Section content ────────────────────────────────────────────────────────────
# Shared
_TABS  = (
    header('📑 Tabs') +
        row('Alt+t',       'New Tab')         +
        row('Alt+Ctrl+t',  'New Tab (WSL)')   +
        row('Alt+[',       'Previous Tab')    +
        row('Alt+]',       'Next Tab')        +
        row('Alt+Ctrl+w',  'Close Tab')       +
        row('Alt+0',       'Rename Tab')      +
        row('Alt+Ctrl+0',  'Undo Rename')     +
        row('Alt+9',       'Toggle Tab Bar')
)

_PANES = (
    header('🪟 Panes') +
        row('Alt+\\',      'Split Vertical')    +
        row('Alt+Ctrl+\\', 'Split Horizontal')  +
        row('Alt+w',       'Close Pane')        +
        row('Alt+Enter',   'Zoom Pane')         +
        row('Alt+Ctrl+↑',  'Focus Up')          +
        row('Alt+Ctrl+↓',  'Focus Down')        +
        row('Alt+Ctrl+←',  'Focus Left')        +
        row('Alt+Ctrl+→',  'Focus Right')       +
        row('Alt+Ctrl+p',  'Swap Panes')
)

_WORKSPACES = (
    header('🗂️  Workspaces') +
        row('F5',          'Search / Switch')    +
        row('Shift+F5',    'New Workspace')      +
        row('Ctrl+F5',     'Rename Workspace')   +
        row('Alt+Ctrl+[',  'Previous Workspace') +
        row('Alt+Ctrl+]',  'Next Workspace')
)

_SCROLLING = (
    header('📜 Scrolling') +
        row('Alt+u',       'Scroll Up 5 lines')   +
        row('Alt+d',       'Scroll Down 5 lines') +
        row('Page Up',     'Scroll Page Up')      +
        row('Page Down',   'Scroll Page Down')    +
        row('End',         'Scroll to Bottom')    +
        row('Shift+↑',     'Jump to Prev Prompt') +
        row('Shift+↓',     'Jump to Next Prompt')
)

_FONT_WIN = (
    header('🔤 Font & Window') +
        row('Alt+=',           'Grow Window')  +
        row('Alt+-',           'Shrink Window')+
        row('Alt+n',           'New Window')   +
        row('Alt+Ctrl+Enter',  'Maximize')
)

_BACKGROUND = (
    header('🖼️  Background Images') +
        row('Alt+/',           'Random Image')          +
        row('Alt+,',           'Previous Category')    +
        row('Alt+.',           'Next Category')        +
        row('Alt+Ctrl+/',      'Browse (live preview)')+
        row('Alt+b',           'Toggle Focus')        +
        row('Alt+r',           'Toggle Auto-Rotate')  +
        row('Alt+Ctrl+,',      'Overlay Opacity ↓')  +
        row('Alt+Ctrl+.',      'Overlay Opacity ↑')  +
        blank() +
        note('Browse: ←/→ navigate · Enter confirm') +
        note('        Esc/q cancel')
)

_ADV_MODES = (
    header('⚙️  Advanced Modes') +
        [f'  {TXT}Leader: {BLD}{YLW}Alt+Ctrl+Space{RST}{TXT}, then:{RST}'] +
        row('  f', 'Font Resize Mode') +
        row('  p', 'Pane Resize Mode') +
        blank() +
        note('Font: ↑/↓ resize, r reset, Esc exit') +
        note('Pane: ↑/↓/←/→ resize, Esc exit')
)

_SESSIONS = (
    header('🗃️  Sessions') +
        row('F9',          'Save Session')        +
        row('F10',         'Restore Session')     +
        row('Shift+F10',   'Save Session (Named)')+
        row('Ctrl+F10',    'Delete Session')
)

_COPY_MODE = (
    header('📋 Copy Mode  [F8]') +
        note('Movement') +
        row('←↑↓→',        'Move cursor')         +
        row('Ctrl+←/→',    'Jump word')            +
        row('Home/End',     'Line start/end')       +
        row('PgUp/PgDn',   'Scroll page')          +
        row('g / G',        'Top / Bottom')         +
        blank() +
        note('Selection') +
        row('v',            'Character select')     +
        row('V',            'Line select')          +
        row('Ctrl+v',       'Block select')         +
        blank() +
        note('Actions') +
        row('y / Enter',    'Copy + exit')          +
        row('/',            'Search')               +
        row('n / N',        'Next / Prev match')    +
        row('q / Esc',      'Exit')
)

_CURSOR_NAV = (
    header('✏️  Cursor & Copy') +
        row('Alt+←',           'Jump to Line Start')    +
        row('Alt+→',           'Jump to Line End')      +
        row('Shift+Enter',     'New line (no submit)')  +
        row('Alt+Backspace',   'Clear Line (Git Bash)') +
        blank() +
        row('Alt+f',           'Search')                +
        row('Alt+Ctrl+u',      'Open URL')              +
        row('Ctrl+Shift+C',    'Copy')                  +
        row('Ctrl+Shift+V',    'Paste')                 +
        row('Right-click',     'Copy / Paste')          +
        row('Alt+Shift+v',     'Paste image path')
)

_LAZYGIT_CMDS = (
    header('🔀 Lazygit Commands') +
        row('Space',       'Stage/unstage file') +
        row('c',           'Commit')             +
        row('P',           'Push')               +
        row('p',           'Pull')               +
        row('Enter',       'Expand file/view diff')+
        row('[ / ]',       'Switch panels')      +
        row('/ (in panel)','Filter list')         +
        row('?',           'Keybindings help')   +
        row('x',           'Open actions menu')  +
        row('+',           'Next screen mode')   +
        row('s',           'Stash changes')      +
        row('S',           'View stash entries') +
        row('n',           'New branch')         +
        row('r',           'Rebase options')     +
        row('M',           'Merge into current') +
        row('z',           'Undo (via reflog)')  +
        row('q',           'Quit')
)

# ── Header ────────────────────────────────────────────────────────────────────
print('\033[2J\033[H', end='', flush=True)
print()
print(f'  {BLD}{BLU}██╗    ██╗███████╗███████╗████████╗███████╗██████╗ ███╗   ███╗{RST}')
print(f'  {BLD}{BLU}██║    ██║██╔════╝╚══███╔╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║{RST}')
print(f'  {BLD}{BLU}██║ █╗ ██║█████╗    ███╔╝    ██║   █████╗  ██████╔╝██╔████╔██║{RST}')
print(f'  {BLD}{BLU}██║███╗██║██╔══╝   ███╔╝     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║{RST}')
print(f'  {BLD}{BLU}╚███╔███╔╝███████╗███████╗   ██║   ███████╗██║  ██║██║ ╚═╝ ██║{RST}')
print(f'  {BLD}{BLU} ╚══╝╚══╝ ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝{RST}')
print(f'\n  {DIM}  Keyboard Shortcuts Cheat Sheet   •   Alt+w to close{RST}')
print()

# ── Band 1: Quick Actions | Tabs | Panes | [Copy Mode] ────────────────────────
_QUICK_ACTIONS = (
    header('🎯 Quick Actions') +
        row('F1',          'Cheat Sheet (this)')    +
        row('F2',          'Command Palette')        +
        row('F3',          'Launcher Menu')          +
        row('F4',          'Fuzzy Tabs')             +
        row('F5',          'Search/Switch Workspace')+
        row('Shift+F5',    'New Workspace')          +
        row('Ctrl+F5',     'Rename Workspace')       +
        row('F6',          'Toggle Notifications')   +
        row('F7',          'SSH Host Selector')      +
        row('F8',          'Copy Mode')              +
        row('F9',          'Save Session')           +
        row('F10',         'Restore Session')        +
        row('Shift+F10',   'Save Session (Named)')   +
        row('Ctrl+F10',    'Delete Session')         +
        row('F11',         'Fullscreen')             +
        row('F12',         'Debug Overlay')
)

if NUM_COLS == 4:
    render_cols(_QUICK_ACTIONS, _TABS, _PANES, _COPY_MODE)
else:
    render_cols(_QUICK_ACTIONS, _TABS, _PANES)
print()

# ── Band 2: Workspaces | Scrolling | Cursor & Copy | [Sessions] ───────────────
if NUM_COLS == 4:
    render_cols(_WORKSPACES, _SCROLLING, _CURSOR_NAV, _SESSIONS)
else:
    render_cols(_WORKSPACES, _SCROLLING, _CURSOR_NAV)
print()

# ── Band 3: Font & Window | Background | Advanced Modes | [] ─────────────────
if NUM_COLS == 4:
    render_cols(_FONT_WIN, _BACKGROUND, _ADV_MODES, [])
else:
    render_cols(_FONT_WIN, _BACKGROUND, _ADV_MODES)
print()

# ── Band 4: File & CLI Tools | More Tools | Lazygit Commands ─────────────────
_YAZI_LNAV = (
    header('📁 File Manager (yazi)') +
        row('Alt+e',           'Open yazi (auto-cd)') +
        blank() +
        note('hjkl navigate • Space select') +
        note('y copy • p paste • / search • q quit') +
        blank() +
        header('📋 lnav') +
        row('lnav FILE',       'Open log file')       +
        row('lnav -r /var/log','Recursive log dir')
)

_EZA_BTOP = (
    header('📂 eza (Modern ls)') +
        row('ls',          'List with icons')      +
        row('ll',          'List all (long)')      +
        row('lt',          'Tree view (2 levels)') +
        blank() +
        header('📊 btop') +
        row('btop',        'Open system monitor')  +
        blank() +
        header('⚡ zoxide') +
        row('z DIR',       'Jump to frecent dir')  +
        row('zi',          'Interactive picker')
)

_GLOW_PKG_FF = (
    header('📄 Glow (Markdown)') +
        row('glow FILE.md','Render markdown')      +
        row('glow',        'Browse md files (TUI)')+
        blank() +
        header('📦 UniGetUI') +
        row('pkgs',        'Open UniGetUI') +
        blank() +
        header('🖥️  Fastfetch') +
        row('fastfetch',   'Show system info panel')
)

if NUM_COLS == 4:
    render_cols(_YAZI_LNAV, _EZA_BTOP, _GLOW_PKG_FF, _LAZYGIT_CMDS)
else:
    _YAZI_LAZYGIT_LNAV = (
        header('📁 File Manager (yazi)') +
            row('Alt+e',           'Open yazi (auto-cd)') +
            blank() +
            note('hjkl navigate • Space select') +
            note('y copy • p paste • / search • q quit') +
            blank() +
            header('🔀 Lazygit') +
            row('lazygit / lg',    'Open in current repo') +
            blank() +
            header('📋 lnav') +
            row('lnav FILE',       'Open log file')       +
            row('lnav -r /var/log','Recursive log dir')
    )
    _EZA_BTOP_GLOW_FF = (
        header('📂 eza (Modern ls)') +
            row('ls',          'List with icons')      +
            row('ll',          'List all (long)')      +
            row('lt',          'Tree view (2 levels)') +
            blank() +
            header('📊 btop') +
            row('btop',        'Open system monitor') +
            blank() +
            header('⚡ zoxide') +
            row('z DIR',       'Jump to frecent dir')  +
            row('zi',          'Interactive picker') +
            blank() +
            header('📄 Glow (Markdown)') +
            row('glow FILE.md','Render markdown')      +
            row('glow',        'Browse md files (TUI)')+
            blank() +
            header('📦 UniGetUI') +
            row('pkgs',        'Open UniGetUI') +
            blank() +
            header('🖥️  Fastfetch') +
            row('fastfetch',   'Show system info panel')
    )
    render_cols(_YAZI_LAZYGIT_LNAV, _EZA_BTOP_GLOW_FF, _LAZYGIT_CMDS)
print()

print(f'  {DIM}  Full docs: github.com/Hassan-Zbib/wezterm-config{RST}')
print()

try:
    while True:
        time.sleep(3600)
except (KeyboardInterrupt, SystemExit):
    pass
