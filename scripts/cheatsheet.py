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
GRN = '\033[38;2;166;218;149m'
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
        if cp in (0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0xFE0E, 0xFEFF, 0xFE0F):
            i += 1
            continue
        ew = unicodedata.east_asian_width(chars[i])
        next_vs16 = i + 1 < len(chars) and ord(chars[i + 1]) == 0xFE0F
        if ew in ('W', 'F'):
            w += 2
            i += 2 if next_vs16 else 1
        elif next_vs16:
            w += 2
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

def sub(label):
    return [f'  {BLD}{GRN}{label}{RST}']

def blank():
    return ['']

def note(text):
    return [f'  {DIM}{text}{RST}']

def render_cols(*cols):
    """Render N columns side by side."""
    n    = max((len(c) for c in cols), default=0)
    sep  = f'{DIM}│{RST}'
    seps = [COL_W + 5 + i * _SLOT_W for i in range(len(cols) - 1)]
    for i in range(n):
        parts = [cols[j][i] if i < len(cols[j]) else '' for j in range(len(cols))]
        line  = parts[0]
        for j, sp in enumerate(seps):
            line += f'\033[{sp}G{sep}  {parts[j + 1]}'
        print(line)

# ── Section content ───────────────────────────────────────────────────────────

# ─── WezTerm Keybindings ──────────────────────────────────────────────────────

_QUICK_ACTIONS = (
    header('🎯 Function Keys') +
        row('F1',          'This cheat sheet')         +
        row('F2',          'Copy mode (vim-like)')     +
        row('F3',          'Launcher menu')            +
        row('F4',          'Fuzzy tab finder')         +
        row('F5',          'Switch workspace')         +
        row('Shift+F5',    'New workspace')            +
        row('Ctrl+F5',     'Rename workspace')         +
        row('F6',          'Toggle OLED mode')         +
        row('F7',          'SSH host picker')          +
        row('F8',          'Command palette')          +
        row('F9',          'Save session')             +
        row('Shift+F10',   'Save session (named)')     +
        row('F10',         'Restore session')          +
        row('Ctrl+F10',    'Delete session')           +
        row('F11',         'Toggle fullscreen')        +
        row('F12',         'Debug overlay')
)

_TABS = (
    header('📑 Tabs') +
        sub('Lifecycle') +
        row('Alt+t',       'New tab')                   +
        row('Alt+Ctrl+t',  'New tab (WSL fish)')        +
        row('Alt+Ctrl+w',  'Close tab')                 +
        blank() +
        sub('Navigation') +
        row('Alt+[',       'Previous tab')              +
        row('Alt+]',       'Next tab')                  +
        blank() +
        sub('Title & Bar') +
        row('Alt+0',       'Rename tab')                +
        row('Alt+Ctrl+0',  'Reset tab title')           +
        row('Alt+9',       'Toggle tab bar')            +
        row('Alt+8',       'Flip tab bar (top/bottom)')
)

_PANES = (
    header('🪟 Panes') +
        sub('Split & Close') +
        row('Alt+\\',      'Split down (pane below)')   +
        row('Alt+Ctrl+\\', 'Split right (pane right)')  +
        row('Alt+w',       'Close pane')                +
        row('Alt+Enter',   'Toggle zoom')               +
        blank() +
        sub('Focus') +
        row('Alt+Ctrl+↑',  'Focus up')                  +
        row('Alt+Ctrl+↓',  'Focus down')                +
        row('Alt+Ctrl+←',  'Focus left')                +
        row('Alt+Ctrl+→',  'Focus right')               +
        row('Alt+Ctrl+p',  'Pick / swap pane')          +
        blank() +
        sub('Resize') +
        row('Alt+Shift+↑↓←→', 'Resize 2 cells')         +
        note('Or use leader → p for resize mode')
)

_WORKSPACES = (
    header('🗂️  Workspaces') +
        row('F5',          'Search & switch')           +
        row('Shift+F5',    'New workspace')             +
        row('Ctrl+F5',     'Rename current')            +
        row('Alt+Ctrl+[',  'Previous workspace')        +
        row('Alt+Ctrl+]',  'Next workspace')
)

_SESSIONS = (
    header('🗃️  Sessions') +
        row('F9',          'Save (auto-named)')         +
        row('Shift+F10',   'Save with custom name')     +
        row('F10',         'Restore (fuzzy picker)')    +
        row('Ctrl+F10',    'Delete saved session')      +
        blank() +
        note('Persists pane layout + workspace')
)

_WINDOW = (
    header('🪟 Window') +
        row('Alt+n',           'New window')            +
        row('Alt+=',           'Grow 50px')             +
        row('Alt+-',           'Shrink 50px')           +
        row('Alt+Ctrl+Enter',  'Toggle maximize')       +
        row('F11',             'Toggle fullscreen')
)

_SCROLLING = (
    header('📜 Scrolling') +
        sub('Page') +
        row('Page Up',     'Page up')                   +
        row('Page Down',   'Page down')                 +
        row('Alt+PgUp',    'Up 5 lines')                +
        row('Alt+PgDn',    'Down 5 lines')              +
        blank() +
        sub('Jump') +
        row('Home',        'Scroll to top')             +
        row('End',         'Scroll to bottom')          +
        row('Shift+↑',     'Previous shell prompt')     +
        row('Shift+↓',     'Next shell prompt')         +
        blank() +
        note('Shell prompt jump needs OSC 133')
)

_CURSOR = (
    header('✏️  Cursor & Clipboard') +
        sub('Line editing (sent to shell)') +
        row('Alt+←',           'Jump to line start')    +
        row('Alt+→',           'Jump to line end')      +
        row('Alt+Backspace',   'Clear line (Git Bash)') +
        row('Shift+Enter',     'Newline w/o submit')    +
        blank() +
        sub('Clipboard') +
        row('Ctrl+Shift+c',    'Copy selection')        +
        row('Ctrl+Shift+v',    'Paste')                 +
        row('Middle-click',    'Copy selection')        +
        row('Right-click',     'Paste')                 +
        row('Alt+Shift+v',     'Paste image as path')   +
        blank() +
        sub('Search') +
        row('Alt+f',           'Find in scrollback')    +
        row('Alt+Ctrl+u',      'Open URL (quick-pick)')
)

_BACKGROUND = (
    header('🖼️  Background & OLED') +
        sub('Image') +
        row('Alt+/',           'Random image')          +
        row('Alt+Ctrl+/',      'Browse (live preview)') +
        row('Alt+Ctrl+,',      'Previous category')     +
        row('Alt+Ctrl+.',      'Next category')         +
        row('Alt+r',           'Toggle auto-rotate')    +
        blank() +
        sub('Display') +
        row('Alt+b',           'Toggle focus mode')     +
        row('Alt+,',           'Overlay opacity −')     +
        row('Alt+.',           'Overlay opacity +')     +
        row('F6',              'Toggle OLED (pure black)') +
        blank() +
        note('Browse: ←/→ next  ·  Enter confirm') +
        note('        Esc/q cancel')
)

_ADV_MODES = (
    header('⚙️  Leader & Modes') +
        sub('Leader: Alt+Ctrl+Space, then…') +
        row('  f',              'Font resize mode')     +
        row('  p',              'Pane resize mode')     +
        blank() +
        note('Font mode: ↑/↓ ±, r reset, Esc/q exit') +
        note('Pane mode: ↑↓←→ resize, Esc/q exit')
)

_COPY_MODE = (
    header('📋 Copy Mode  [F2]') +
        sub('Movement') +
        row('h j k l / ←↓↑→',  'Move cursor')           +
        row('w / b / e',       'Word forward/back/end') +
        row('Ctrl+←/→',        'Jump word')             +
        row('0 / ^ / $',       'Line start/content/end')+
        row('Home / End',      'Line start/end')        +
        row('g / G',           'Top / bottom')          +
        row('H / M / L',       'Viewport top/mid/bot')  +
        row('PgUp/PgDn',       'Page up / down')        +
        row('Ctrl+u / Ctrl+d', 'Half page up/down')     +
        blank() +
        sub('Selection') +
        row('v',               'Cell select')           +
        row('V',               'Line select')           +
        row('Ctrl+v',          'Block select')          +
        blank() +
        sub('Actions') +
        row('y / Enter',       'Copy & exit')           +
        row('/',               'Search')                +
        row('n / N',           'Next / prev match')     +
        row('Ctrl+g',          'Clear search pattern')  +
        row('q / Esc',         'Exit')
)

# ─── CLI Tools ────────────────────────────────────────────────────────────────

_FILE_TOOLS = (
    header('📁 File Manager') +
        row('Alt+e',           'Open yazi here')        +
        blank() +
        sub('eza (modern ls)') +
        row('ls',              'List (dirs first, git)')+
        row('la',              'List incl. hidden')     +
        row('ll',              'Long + git + header')   +
        row('lt',              'Tree view (2 levels)')  +
        blank() +
        sub('zoxide (smart cd)') +
        row('z DIR',           'Jump to frecent dir')   +
        row('zi',              'Interactive picker')    +
        blank() +
        sub('fzf') +
        row('fzf',             'Fuzzy-find files')      +
        row('Ctrl+r',          'Fuzzy history search')
)

_VIEWERS = (
    header('📄 Viewers & System') +
        sub('Glow (markdown)') +
        row('glow FILE.md',    'Render markdown')       +
        row('glow',            'Browse md files (TUI)') +
        blank() +
        sub('lnav (logs)') +
        row('lnav FILE',       'Open log file')         +
        row('lnav -r DIR',     'Recursive log dir')     +
        blank() +
        sub('btop / fastfetch') +
        row('btop',            'System monitor')        +
        row('fastfetch · ff',  'System info panel')     +
        blank() +
        sub('UniGetUI') +
        row('pkgs',            'Open package manager')
)

_LAZY_TOOLS = (
    header('🔀 Lazy Tools') +
        sub('Lazygit  (lazygit / lg)') +
        row('Space',           'Stage / unstage')       +
        row('c',               'Commit')                +
        row('P / p',           'Push / pull')           +
        row('Enter',           'Expand · view diff')    +
        row('[ / ]',           'Switch panels')         +
        row('/',               'Filter list')           +
        row('?',               'Keybindings help')      +
        row('x',               'Actions menu')          +
        row('+',               'Next screen mode')      +
        row('s / S',           'Stash / view stash')    +
        row('n',               'New branch')            +
        row('r',               'Rebase options')        +
        row('M',               'Merge into current')    +
        row('z',               'Undo (via reflog)')     +
        row('q',               'Quit')                  +
        blank() +
        sub('Lazyssh & LazySkills') +
        row('lazyssh / lssh',  'SSH manager')           +
        row('lazyskills',      'Manage agent skills')
)

# ─── Yazi keybindings ─────────────────────────────────────────────────────────

_YAZI_NAV = (
    header('📁 Yazi — Navigation') +
        row('j / k  ·  ↓ / ↑',  'Move down / up')       +
        row('h  ·  ←',          'Parent directory')     +
        row('l  ·  →',          'Enter / open')         +
        row('gg / G',           'Top / bottom of list') +
        row('Ctrl+PgUp/PgDn',   'Half page up/down')    +
        row('H / L',            'History back / forward')+
        row('~',                'Home directory')       +
        blank() +
        sub('Search & filter') +
        row('/',                'Search')               +
        row('n / N',            'Next / prev match')    +
        row('f',                'Filter list')          +
        row('.',                'Toggle hidden files')  +
        row('z',                'Jump with zoxide')
)

_YAZI_OPS = (
    header('📋 Yazi — File Operations') +
        sub('Clipboard') +
        row('y',                'Yank (copy)')          +
        row('x',                'Cut')                  +
        row('p',                'Paste')                +
        blank() +
        sub('Modify') +
        row('d',                'Move to trash')        +
        row('D',                'Delete permanently')   +
        row('r',                'Rename')               +
        row('a',                'Create (suffix / = dir)')+
        blank() +
        sub('Selection') +
        row('Space',            'Toggle select')        +
        row('v',                'Visual select mode')   +
        row('V',                'Select all')           +
        row('u',                'Deselect all')
)

_YAZI_MISC = (
    header('🔍 Yazi — Tabs & Misc') +
        sub('View') +
        row('Tab',              'Toggle preview panel') +
        blank() +
        sub('Tabs') +
        row('t',                'New tab')              +
        row('[ / ]',            'Prev / next tab')      +
        row('1 – 9',            'Go to tab N')          +
        blank() +
        sub('Run') +
        row('e',                'Open in editor')       +
        row('!',                'Open shell here')      +
        row('w',                'Task manager')         +
        blank() +
        sub('Exit') +
        row('q',                'Quit (cd to current)') +
        row('Q',                'Quit (no cd)')
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

def section_title(label):
    line = '═' * (COL_W + 4)
    print(f'  {BLD}{BLU}{line}{RST}')
    print(f'  {BLD}{BLU}  {label}{RST}')
    print(f'  {BLD}{BLU}{line}{RST}')
    print()

# ── Section: WezTerm Core ─────────────────────────────────────────────────────
section_title('WEZTERM  ·  CORE')

if NUM_COLS == 4:
    render_cols(_QUICK_ACTIONS, _TABS, _PANES, _COPY_MODE)
else:
    render_cols(_QUICK_ACTIONS, _TABS, _PANES)
print()

# ── Section: WezTerm Workflow ─────────────────────────────────────────────────
section_title('WEZTERM  ·  WORKFLOW')

if NUM_COLS == 4:
    render_cols(_WORKSPACES, _SESSIONS, _WINDOW, _SCROLLING)
else:
    render_cols(_WORKSPACES, _SESSIONS, _WINDOW)
    print()
    render_cols(_SCROLLING, _CURSOR, _BACKGROUND)
    print()
    render_cols(_ADV_MODES, _COPY_MODE, [])
print()

# ── Section: WezTerm Editing & Appearance (4-col only) ────────────────────────
if NUM_COLS == 4:
    render_cols(_CURSOR, _BACKGROUND, _ADV_MODES, [])
    print()

# ── Section: CLI Tools ────────────────────────────────────────────────────────
section_title('CLI  TOOLS')

if NUM_COLS == 4:
    render_cols(_FILE_TOOLS, _VIEWERS, _LAZY_TOOLS, [])
else:
    render_cols(_FILE_TOOLS, _VIEWERS, _LAZY_TOOLS)
print()

# ── Section: Yazi ─────────────────────────────────────────────────────────────
section_title('YAZI  FILE  MANAGER')

if NUM_COLS == 4:
    render_cols(_YAZI_NAV, _YAZI_OPS, _YAZI_MISC, [])
else:
    render_cols(_YAZI_NAV, _YAZI_OPS, _YAZI_MISC)
print()

print(f'  {DIM}  Full docs: github.com/Hassan-Zbib/wezterm-config{RST}')
print()

try:
    while True:
        time.sleep(3600)
except (KeyboardInterrupt, SystemExit):
    pass
