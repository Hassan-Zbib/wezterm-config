#!/usr/bin/env python
"""WezTerm Cheat Sheet — Catppuccin Macchiato

An interactive, tabbed pager. One section per screen; ←/→ cycles, digits jump.
Falls back to printing every page in sequence when stdout is not a terminal,
which is also how the layout is regression-checked (`--all`).
"""

import os
import re
import sys
import json
import time
import shutil
import threading
import subprocess
import unicodedata
import urllib.request

# ── Colors ────────────────────────────────────────────────────────────────────
BLU = '\033[38;2;138;173;244m'
YLW = '\033[38;2;238;212;159m'
CYN = '\033[38;2;125;196;228m'
GRN = '\033[38;2;166;218;149m'
DIM = '\033[38;2;110;115;141m'
TXT = '\033[38;2;202;211;245m'
BLD = '\033[1m'
UND = '\033[4m'
RST = '\033[0m'

COL_W   = 46
ANSI    = re.compile(r'\x1b\[[0-9;]*[A-Za-z]')   # colours (m) and cursor moves (G)
_SLOT_W = COL_W + 7            # width of one column slot (content + sep + gaps)

# herdr's prefix key, which opens ~30 of the rows below. It is configured in
# %APPDATA%\herdr\config.toml (symlinked from home/), and lives here as a single
# constant so that changing it there is a one-line change here too rather than a
# find-and-replace across every herdr panel.
HERDR_PREFIX = '`'


def num_cols(width):
    """How many panel columns fit in `width`. 4 needs >=209 chars, 3 needs >=156."""
    return max(1, min(4, (width + 3) // _SLOT_W))


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


def trunc(text, width):
    """Cut to `width` display columns, with an ellipsis when it does not fit."""
    if wlen(text) <= width:
        return text
    out = ''
    for ch in text:
        if wlen(out) + wlen(ch) > width - 1:
            break
        out += ch
    return out + '…'

# ── Builders ──────────────────────────────────────────────────────────────────
# Panels are pre-coloured lines, which throws away the (key, desc) pair search
# needs, so row() records each pair as a side effect while panels are built.
# Panels always open with header(), so the latest title owns the row. Rows also
# inherit the sub() heading above them, so tool names that only appear as a
# heading -- "lazygit", "eza", "zoxide" -- still match.
_ROWS     = []         # (panel title, sub heading, key, desc) in definition order
_NOTES    = {}         # panel title -> [note text]; searched as a fallback only
_PANEL    = [None]
_SUB      = [None]

# The home page is re-composed whenever the version check advances, which runs
# row()/note() again long after INDEX was built. Recording is switched off after
# the import pass so those rebuilds do not append duplicates to _ROWS/_NOTES.
_RECORD   = [True]


def header(title, width=COL_W):
    """Panel title and its rule. `width` only varies for single-panel pages,
    where the rule can be drawn to match content wider than a column."""
    _PANEL[0] = title
    _SUB[0] = None
    return [
        f'{BLD}{CYN}  {title}{RST}',
        f'{DIM}  {"─" * width}{RST}',
    ]

def row(key, desc):
    if _RECORD[0]:
        _ROWS.append((_PANEL[0], _SUB[0], key, desc))
    # At least one space: a key of 22 columns or more would otherwise run
    # straight into its description with no gap at all.
    pad = max(22 - wlen(key), 1)
    return [f'  {BLD}{YLW}{key}{RST}{" " * pad}{TXT}{desc}{RST}']

def sub(label):
    _SUB[0] = label
    return [f'  {BLD}{GRN}{label}{RST}']

def blank():
    return ['']

def note(text):
    if _RECORD[0]:
        _NOTES.setdefault(_PANEL[0], []).append(text)
    return [f'  {DIM}{text}{RST}']

def compose_cols(cols):
    """Lay N panels side by side and return the composed lines."""
    cols = [c for c in cols if c]
    if not cols:
        return []
    n    = max(len(c) for c in cols)
    sep  = f'{DIM}│{RST}'
    seps = [COL_W + 5 + i * _SLOT_W for i in range(len(cols) - 1)]
    out  = []
    for i in range(n):
        parts = [cols[j][i] if i < len(cols[j]) else '' for j in range(len(cols))]
        line  = parts[0]
        for j, sp in enumerate(seps):
            line += f'\033[{sp}G{sep}  {parts[j + 1]}'
        out.append(line)
    return out

# ── Section content ───────────────────────────────────────────────────────────

# ─── WezTerm Keybindings ──────────────────────────────────────────────────────

# The canonical index of every F-key. Topic panels below deliberately do NOT
# repeat these rows -- they point back here instead.
_QUICK_ACTIONS = (
    header('🎯 Function Keys') +
        row('F1',          'This cheat sheet')         +
        row('F2',          'Copy mode (vim-like)')     +
        row('F3',          'Launcher menu')            +
        row('F4',          'Fuzzy tab finder')         +
        row('F5',          'Workspaces & sessions')    +
        row('F6',          'Save session')             +
        row('F7',          'SSH host picker')          +
        row('F8',          'Command palette')          +
        row('F11',         'Toggle fullscreen')        +
        row('F12',         'Debug overlay')
)

# Every "new tab" binding lives here, including the domain-specific ones --
# Domains & Mux points back rather than listing them twice.
_TABS = (
    header('📑 Tabs') +
        sub('Lifecycle') +
        row('Alt+t',       'New tab')                   +
        row('Alt+Ctrl+t',  'New tab (local, temp)')     +
        row('Alt+Ctrl+Shift+t', 'New tab (WSL Ubuntu)') +
        row('Alt+Ctrl+w',  'Close tab')                 +
        blank() +
        sub('Navigation') +
        row('Alt+[',       'Previous tab')              +
        row('Alt+]',       'Next tab')                  +
        row('Alt+1 – 9',   'Jump to tab N')             +
        row('Ctrl+Shift+←', 'Move tab left')            +
        row('Ctrl+Shift+→', 'Move tab right')           +
        blank() +
        sub('Title & Bar') +
        row('Alt+0',       'Rename tab')                +
        row('Alt+Ctrl+0',  'Reset tab title')           +
        row('Alt+Ctrl+9',  'Toggle tab bar')            +
        row('Alt+Ctrl+8',  'Flip bar (top/bottom)')     +
        blank() +
        note('Alt+1–9 matches herdr\'s') +
        note(f'{HERDR_PREFIX} 1–9 — same digits,') +
        note('prefix swapped for Alt.')
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
        row('Alt+Shift+↑↓←→', 'Resize 2 cells')
)

_WORKSPACES = (
    header('🗂️  Workspaces') +
        row('Alt+Ctrl+[',  'Previous workspace')        +
        row('Alt+Ctrl+]',  'Next workspace')            +
        blank() +
        sub('In the F5 hub') +
        row('Switch workspace', 'Fuzzy picker')         +
        row('New workspace',    'Prompts for a name')   +
        row('Rename workspace', 'Renames current')      +
        blank() +
        note('Switching never pauses a') +
        note('workspace — builds and agents') +
        note('keep running in the background.')
)

_MUX = (
    header('🔌 Domains & Mux') +
        row('Alt+Ctrl+m',  'Domain / mux manager')      +
        blank() +
        note('Per-domain new-tab keys are on') +
        note('the Tabs panel; SSH hosts on F7.') +
        blank() +
        note('WSL tabs open in ~ (ext4), not') +
        note('/mnt/c — and persist like the') +
        note('rest. Windows stays default.') +
        blank() +
        sub('Manager menu') +
        row('<domain>',    'New tab in domain')         +
        row('Attach "mux"','Reconnect persistent')      +
        row('Detach',      'Leave, keep running')       +
        row('Restart',     'Restart mux (confirm)')     +
        blank() +
        note('Tabs live in a background mux') +
        note('server — closing the window') +
        note('leaves agents running.') +
        blank() +
        note('Restart the mux after editing') +
        note('default_prog or domains:') +
        note('Ctrl+Shift+r reloads the GUI') +
        note('only, not the server.')
)

_SESSIONS = (
    header('🗃️  Sessions') +
        row('F6',          'Save / update')             +
        blank() +
        sub('In the F5 hub') +
        row('Restore',        'Rebuild a session')      +
        row('Restore as',     'Into another workspace') +
        row('Save as',        'Fork under a new name')  +
        row('Rename / Delete', 'Manage saved ones')     +
        blank() +
        note('Saves the WHOLE workspace:') +
        note('windows, tabs, splits, cwd,') +
        note('domain, zoom and focus.') +
        note('F6 updates the session this') +
        note('workspace is attached to.') +
        note('No programs or scrollback -') +
        note('impossible over the mux.') +
        note('~/.config/wezterm/sessions')
)

_WINDOW = (
    header('🪟 Window') +
        row('Alt+n',           'New window')            +
        row('Alt+=',           'Grow 50px')             +
        row('Alt+-',           'Shrink 50px')           +
        row('Alt+Ctrl+Enter',  'Toggle maximize')       +
        row('Ctrl+Shift+r',    'Reload config')         +
        blank() +
        note('Fullscreen is F11.')
)

_SCROLLING = (
    header('📜 Scrolling') +
        sub('Page') +
        row('Shift+PgUp',  'Page up')                   +
        row('Shift+PgDn',  'Page down')                 +
        row('Alt+PgUp',    'Up 5 lines')                +
        row('Alt+PgDn',    'Down 5 lines')              +
        blank() +
        sub('Jump') +
        row('Shift+Home',  'Scroll to top')             +
        row('Shift+End',   'Scroll to bottom')          +
        blank() +
        note('Scrolling lives on a modifier.') +
        note('Bare PgUp/PgDn/Home/End are') +
        note('unbound so the app gets them') +
        note('(Claude Code, yazi, vim, less,') +
        note('and zsh line start/end).') +
        blank() +
        note('No prompt-jump: semantic zones') +
        note('do not cross the mux boundary') +
        note('(wezterm PR #8078); Shift+↑/↓') +
        note('are left free for zsh.')
)

# Paired keys share a row rather than getting one line each -- Ctrl+Backspace
# and Alt+Backspace are the same widget, and listing them apart read as two
# different bindings.
_CURSOR = (
    header('✏️  Cursor & Clipboard') +
        sub('Line editing (sent to shell)') +
        row('Alt+←  ·  Alt+→',      'Line start / end')    +
        row('Ctrl+←  ·  Ctrl+→',    'Word left / right')   +
        row('Ctrl+Bksp · Alt+Bksp', 'Delete word left')    +
        row('Ctrl+Del · Alt+Del',   'Delete word right')   +
        row('Ctrl+w',               'Delete to whitespace')+
        row('Ctrl+u',               'Delete to line start')+
        row('Ctrl+Shift+Bksp',      'Clear whole line')    +
        row('Shift+Enter',          'Newline w/o submit')  +
        blank() +
        note('Bound in ~/.zshrc (zsh)') +
        note('Git Bash still on F3.') +
        note('When ghost text is showing,') +
        note('→ and Ctrl+→ also accept it —') +
        note('see the Zsh page.') +
        blank() +
        sub('Clipboard') +
        row('Ctrl+Shift+c · Middle', 'Copy selection')     +
        row('Ctrl+Shift+v · Right',  'Paste')              +
        row('Alt+Shift+v',           'Paste image as path')+
        blank() +
        sub('Search') +
        row('Alt+f',                 'Find in scrollback') +
        row('Alt+Ctrl+u',            'Open URL (quick-pick)')
)

_BACKGROUND = (
    header('🖼️  Background') +
        sub('Image') +
        row('Alt+/',           'Random image')          +
        row('Alt+Ctrl+/',      'Browse & cull')         +
        row('Alt+Ctrl+,',      'Previous category')     +
        row('Alt+Ctrl+.',      'Next category')         +
        row('Alt+r',           'Toggle auto-rotate')    +
        blank() +
        sub('Display') +
        row('Alt+b',           'Toggle focus mode')     +
        row('Alt+,',           'Overlay opacity −')     +
        row('Alt+.',           'Overlay opacity +')     +
        blank() +
        note('Browse: ←/→/k next  ·  Enter keep') +
        note('        Esc/q revert') +
        note('Cull:   d/x recycle-bin  ·  u undo') +
        note('        both exits commit')
)

_ADV_MODES = (
    header('⚙️  Leader & Modes') +
        sub('Leader: Alt+Ctrl+Space, then…') +
        row('  f',              'Font resize mode')     +
        blank() +
        note('Font mode: ↑/↓ ±, r reset, Esc/q exit') +
        blank() +
        note('Panes resize with Alt+Shift+↑↓←→') +
        note('directly — no mode needed.')
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
        row('yy',              'Open yazi here')        +
        note('Wrapper around yazi: auto-cds') +
        note('to the selected dir on quit.') +
        note('Its keys are on the Yazi page.') +
        blank() +
        sub('eza (modern ls)') +
        row('ls',              'List (dirs first, git)')+
        row('la',              'List incl. hidden')     +
        row('ll',              'Long + git + header')   +
        row('lt',              'Tree view (2 levels)')  +
        blank() +
        sub('zoxide (smart cd)') +
        row('z / cd DIR',      'Jump to frecent dir')   +
        row('zi / cdi',        'Interactive picker')    +
        blank() +
        sub('fzf') +
        row('fzf',             'Fuzzy-find files')      +
        note('Key bindings are on the Zsh page.')
)

_VIEWERS = (
    header('📄 Viewers & System') +
        sub('Glow (markdown)') +
        row('glow FILE.md',    'Render markdown')       +
        row('glow',            'Browse md files (TUI)') +
        blank() +
        sub('fastfetch') +
        row('fastfetch · ff',  'System info panel')     +
        blank() +
        sub('btop (system monitor)') +
        row('btop · bt',       'CPU · RAM · disk · net')+
        row('F1 · h',          'Help — every key')      +
        row('F2 · o',          'Options menu')          +
        row('Esc · m',         'Main menu')             +
        row('1 2 3 4',         'Toggle the four boxes') +
        row('p / shift+p',     'Cycle view presets')    +
        row('f · e · r',       'Filter · tree · sort')  +
        row('t',               'Kill selected process') +
        blank() +
        sub('UniGetUI') +
        row('pkgs',            'Open package manager')   +
        blank() +
        sub('Claude Code') +
        row('ccp',             'Switch creds profile')  +
        blank() +
        sub('Shells') +
        row('zsh',             'Start zsh (default)')   +
        row('bash',            'Start Git Bash')        +
        row('pwsh',            'Start PowerShell 7')    +
        row('wsl',             'Ubuntu via WSL')        +
        note('Each runs inside the current') +
        note('pane — exit returns you back.') +
        note('In pwsh, bash is Git Bash —') +
        note('use wsl-bash for Ubuntu.')
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
        sub('delta (diff renderer)') +
        note('Renders lazygit diffs:') +
        note('syntax colours + line nums.') +
        note('Tuned in ~/.gitconfig [delta].') +
        blank() +
        sub('Lazyssh & LazySkills') +
        row('lazyssh / lssh',  'SSH manager')           +
        row('lazyskills',      'Manage agent skills')
)

# ─── Starship prompt ──────────────────────────────────────────────────────────
# Legend for the segments that are not self-explanatory. The prompt is one
# shared ~/.config/starship.toml, so this is identical in zsh, bash and pwsh.
# Keep in sync with home/.config/starship.toml.
#
# Glyphs are written as \u escapes rather than pasted literally: Nerd Font
# icons live in the Unicode Private Use Area, which a number of editors and
# tools silently drop on save. Escapes keep this file pure ASCII and record
# which codepoint each icon actually is.
_G_LVL    = '\ueb03'      # layers      · shell nesting depth
_G_COMMIT = '\uf417'      # git-commit  · detached HEAD
_G_PKG    = '\uf487'      # package     · project version
_G_DEL    = '\U000f0a79'  # trash       · deleted file
_G_AHEAD  = '\U000f0737'  # arrow-up    · commits ahead
_G_BEHIND = '\U000f072e'  # arrow-down  · commits behind
_G_ERR    = '\uf00d'      # times       · exit status
_G_JOBS   = '\uf0ae'      # tasks       · background jobs
_G_CLOCK  = '\ueaf4'      # watch       · command duration
_G_HOST   = '\uf233'      # server      · remote host

_PROMPT = (
    header('⚡ Prompt (starship)') +
        sub('Left bar') +
        row(f'{_G_LVL} 2',            'Shells deep (always on)') +
        row('dim path / bold',        'Repo root emphasised')    +
        row(f'{_G_COMMIT} f23d8cf',   'Detached HEAD')           +
        row(f'{_G_PKG} v1.2.3',       'Project version')         +
        blank() +
        sub('Git status') +
        row('!  ?',                   'modified · untracked')    +
        row('+  »',                   'staged · renamed')        +
        row(f'{_G_DEL}  =',           'deleted · conflict')      +
        row('$',                      'stashed')                 +
        row(f'{_G_AHEAD}2  {_G_BEHIND}1', 'ahead · behind')      +
        row('(REBASING 1/3)',         'Operation in progress')   +
        blank() +
        sub('Right side') +
        row(f'{_G_ERR} 130 INT',      'Exit code + signal')      +
        row(f'{_G_ERR} 1|0|1',        'Pipeline exit codes')     +
        row(f'{_G_JOBS}2',            'Background jobs')         +
        row(f'{_G_CLOCK} 12s345ms',   'Took longer than 2s')     +
        row(f'{_G_HOST} host',        'Only when SSH-ed')        +
        blank() +
        note('Every segment hides itself') +
        note('when it has nothing to say.')
)

# ─── Zsh ──────────────────────────────────────────────────────────────────────
# Only what zsh actually gives you over bash in THIS setup -- everything here is
# verified working, not aspirational. Add new capabilities as they land
# (plugins, options, keybindings), and keep them in sync with ~/.zshrc.

_ZSH_FUZZY = (
    header('🔮 Zsh — Fuzzy (fzf)') +
        row('Ctrl+t',          'Insert file path')      +
        row('Alt+c',           'cd into subdir')        +
        row('**<Tab>',         'Fuzzy-complete path')   +
        note('Ctrl+r belongs to atuin, not') +
        note('fzf — see the Atuin page.') +
        blank() +
        sub('fzf-tab') +
        row('Tab',             'Picker with preview')   +
        row(', / .',           'Switch result group')   +
        note('Dirs preview via eza,') +
        note('files via bat.') +
        blank() +
        note('Bash has the fzf binary but') +
        note('none of these bindings.')
)

_ZSH_GLOB = (
    header('🌐 Zsh — Globbing') +
        row('**/*.lua',        'Recurse subdirs')       +
        row('*(.)',            'Plain files only')      +
        row('*(/)',            'Directories only')      +
        row('*(om[1,5])',      '5 most recent')         +
        row('*.lua(.om[1,2])', 'Qualifiers stack')      +
        blank() +
        note('Bash needs shopt -s globstar') +
        note('for ** and has no qualifiers.') +
        blank() +
        sub('Helpers') +
        row('cat FILE',        'bat, syntax coloured')  +
        row('catp FILE',       'bat, no line numbers')  +
        note('Unknown command → plain zsh') +
        note('error; winget search NAME') +
        note('looks a package up by hand.')
)

_ZSH_SHELL = (
    header('🧠 Zsh — Completion & History') +
        sub('Completion') +
        row('Tab',             'Complete / list')       +
        row('Tab Tab',         'Cycle through matches') +
        row('Ctrl+d',          'List all matches')      +
        note('carapace supplies flags and') +
        note('subcommands for ~500 CLIs —') +
        note('docker, kubectl, aws, gh, git.') +
        blank() +
        sub('Suggestions') +
        row('→  ·  Alt+→',     'Accept whole suggestion')+
        row('Ctrl+→',          'Accept one word')       +
        note('Same keys as word/line motion —') +
        note('they accept only while ghost') +
        note('text is showing. Drawn from') +
        note("atuin's DB, not the ring.") +
        blank() +
        sub('History') +
        note('Owned by atuin — see the Atuin') +
        note('page. zsh keeps only a session') +
        note('ring, for !! and !$.')
)

# ─── Atuin ────────────────────────────────────────────────────────────────────
# atuin replaced zsh's own history entirely (SAVEHIST=0, no HISTFILE), so this
# is the only reference for how history works in this setup. Keep it in sync
# with ~/.config/atuin/config.toml -- several rows below describe settings that
# depart from atuin's defaults and would otherwise be wrong.

_ATUIN_SEARCH = (
    header('🔍 Atuin — Search') +
        sub('Open it') +
        row('Ctrl+r',          'Search everything')     +
        row('↑',               'Search this folder')    +
        note('Enter runs the command right') +
        note('away. Tab is the safe one: it') +
        note('fills the prompt instead.') +
        blank() +
        sub('Inside the picker') +
        row('↑ / ↓',           'Move selection')        +
        row('Enter',           'Run it immediately')    +
        row('Tab',             'Put on prompt + edit')  +
        row('Ctrl+y',          'Copy to clipboard')     +
        row('Ctrl+o',          'Inspector: runs, stats')+
        row('Esc  ·  Ctrl+g',  'Cancel, keep typing')   +
        note('There are no jump-to-row digits:') +
        note('Alt+1..9 are WezTerm tab keys, so') +
        note('they are switched off in atuin.')
)

_ATUIN_FILTER = (
    header('🎯 Atuin — Scope & Edit') +
        sub('Filter scope — Ctrl+r cycles') +
        row('global',          'Everything, all hosts') +
        row('host',            'This machine only')     +
        row('session',         'This shell session')    +
        row('directory',       'This folder or repo')   +
        note('Ctrl+r opens on global, ↑ opens') +
        note('on directory. A git repo counts') +
        note('as one folder.') +
        blank() +
        sub('Match mode — Ctrl+s cycles') +
        row('fuzzy',           'Default; loose match')  +
        row('prefix',          'Starts with')           +
        row('fulltext',        'Contains anywhere')     +
        blank() +
        sub('Edit & delete') +
        row('Ctrl+w',          'Delete word back')      +
        row('Ctrl+u',          'Clear the query')       +
        row('Ctrl+a  then  d', 'Delete this entry')     +
        row('Ctrl+a  then  D', 'Delete all matching')   +
        note('Ctrl+a is a prefix key here, so') +
        note('Ctrl+a then a goes to line start.')
)

_ATUIN_CLI = (
    header('🧬 Atuin — AI & CLI') +
        sub('Ask the AI') +
        row('?',               'Ask in plain English')  +
        note('Only on an empty prompt, so a') +
        note('glob like ls ?x is unaffected.') +
        note('It cannot read command output') +
        note('on Windows — no pty-proxy.') +
        blank() +
        sub('Everyday CLI') +
        row('atuin stats',     'Most-used commands')    +
        row('atuin doctor',    'Check the setup')       +
        row('atuin info',      'Config and DB paths')   +
        row('atuin import zsh','Re-ingest a histfile')  +
        blank() +
        sub('Scripts — saved snippets') +
        row('atuin scripts new N', 'Save one')          +
        row('atuin scripts list',  'List them')         +
        note('scripts run is broken on Windows') +
        note('(upstream bug), so these are') +
        note('storage only for now.') +
        blank() +
        note('Sync is OFF. Nothing leaves this') +
        note('machine; the account exists only') +
        note('so the AI will answer.')
)

# ─── Yazi keybindings ─────────────────────────────────────────────────────────

_YAZI_NAV = (
    header('📁 Yazi — Navigation') +
        row('j / k  ·  ↓ / ↑',  'Move down / up')       +
        row('h  ·  ←',          'Parent directory')     +
        row('l  ·  →',          'Enter / open')         +
        row('gg / G',           'Top / bottom of list') +
        row('PgUp / PgDn',      'Full page up/down')    +
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

# ─── WezTerm CLI ──────────────────────────────────────────────────────────────
# `wezterm cli` talks to the running mux server over its socket, so these work
# from any pane -- and from a script or an agent -- without touching the GUI.
# Most subcommands default to $WEZTERM_PANE, which the GUI exports into every
# pane, so the common case needs no --pane-id at all.

_WEZ_CLI_PANES = (
    header('🧰 wezterm cli — Panes') +
        note('Every row below is prefixed') +
        note('with `wezterm cli`.') +
        blank() +
        sub('Create (prints pane-id)') +
        row('split-pane --right', 'Split rightward')     +
        row('split-pane --bottom', 'Split downward')     +
        row('  --cells <n>',    'Size in cells')         +
        row('  --top-level',    'Split whole window')    +
        row('spawn --new-window', 'New window')          +
        row('spawn --cwd <dir>', 'New tab in a dir')     +
        row('move-pane-to-new-tab', 'Pane becomes a tab')+
        blank() +
        sub('activate-pane-direction') +
        row('left | right',     'Focus adjacent pane')   +
        row('up | down',        'Focus adjacent pane')   +
        blank() +
        sub('Modify') +
        row('kill-pane',        'Close a pane')          +
        row('zoom-pane --toggle', 'Zoom / unzoom')       +
        row('adjust-pane-size', 'Resize directionally')
)

_WEZ_CLI_QUERY = (
    header('🧰 wezterm cli — Query & Text') +
        sub('Inspect') +
        row('list',             'Windows/tabs/panes')    +
        row('list --format json', 'Machine readable')    +
        row('list-clients',     'Attached clients')      +
        blank() +
        sub('Read pane text') +
        row('get-text',         'Dump pane contents')    +
        row('  --start-line -n', 'Into the scrollback')  +
        row('  --escapes',      'Keep colours')          +
        blank() +
        sub('Write to a pane') +
        row('send-text "<cmd>"', 'Paste into a pane')    +
        row('  --no-paste',     'Send raw, unpasted')    +
        blank() +
        sub('Titles') +
        row('set-tab-title',    'Rename a tab')          +
        row('set-window-title', 'Rename a window')       +
        row('rename-workspace', 'Rename a workspace')    +
        blank() +
        note('--pane-id targets any pane;') +
        note('it defaults to $WEZTERM_PANE.')
)

_WEZ_CLI_TOP = (
    header('🧰 wezterm — Top-level') +
        note('Every row below is prefixed') +
        note('with `wezterm`.') +
        blank() +
        sub('Launch') +
        row('start -- <cmd>',   'GUI running a command') +
        row('connect mux',      'Attach the mux')        +
        row('ssh <host>',       'SSH without a domain')  +
        row('serial <port>',    'Open a serial port')    +
        blank() +
        sub('Inspect') +
        row('show-keys',        'Every key assignment')  +
        row('show-keys --lua',  'Emit as Lua config')    +
        row('ls-fonts',         'Font resolution')       +
        row('  --list-system',  'All system fonts')      +
        blank() +
        sub('Terminal tricks') +
        row('imgcat <file>',    'Show image inline')     +
        row('record / replay',  'asciicast a session')   +
        row('set-working-directory', 'Emit OSC 7')       +
        row('shell-completion <sh>', 'Gen completions')  +
        blank() +
        sub('Config override') +
        row('-n',               'Skip wezterm.lua')      +
        row('--config <k=v>',   'Override one setting')
)

# ─── herdr ────────────────────────────────────────────────────────────────────
# herdr is an agent-aware multiplexer running INSIDE a WezTerm pane, so both
# layers are live at once. Its bindings mirror the WezTerm ones above by one
# rule: drop Alt, add the prefix, keep Ctrl where WezTerm used Alt+Ctrl. They
# cannot collide -- WezTerm sees every keystroke first, which is also why the
# F-key half of the scheme is not mirrored.
#
# Config: home/AppData/Roaming/herdr/config.toml, symlinked by dotbot.

_HERDR_PANES = (
    header('🐑 herdr — Panes') +
        note(f'Prefix: tap {HERDR_PREFIX} (above Tab),') +
        note('release, then press the key.') +
        blank() +
        sub('Split & Close') +
        row(f'{HERDR_PREFIX}  \\',       'Split stacked')        +
        row(f'{HERDR_PREFIX}  Ctrl+\\',  'Split side-by-side')   +
        row(f'{HERDR_PREFIX}  w',        'Close pane')           +
        row(f'{HERDR_PREFIX}  Enter',    'Toggle zoom')          +
        blank() +
        sub('Focus') +
        row(f'{HERDR_PREFIX}  ↑↓←→',     'Focus pane')           +
        row(f'{HERDR_PREFIX}  Tab',      'Cycle next pane')      +
        row(f'{HERDR_PREFIX}  Shift+Tab', 'Cycle previous')      +
        blank() +
        sub('Resize & Misc') +
        row(f'{HERDR_PREFIX}  r',        'Resize mode (arrows)') +
        row(f'{HERDR_PREFIX}  Shift+P',  'Rename pane')          +
        row(f'{HERDR_PREFIX}  e',        'Edit scrollback')
)

_HERDR_TABS = (
    header('🐑 herdr — Tabs') +
        sub('Lifecycle') +
        row(f'{HERDR_PREFIX}  t',        'New tab')              +
        row(f'{HERDR_PREFIX}  Ctrl+w',   'Close tab')            +
        blank() +
        sub('Navigation') +
        row(f'{HERDR_PREFIX}  [',        'Previous tab')         +
        row(f'{HERDR_PREFIX}  ]',        'Next tab')             +
        row(f'{HERDR_PREFIX}  1 – 9',    'Jump to tab N')        +
        blank() +
        sub('Naming') +
        row(f'{HERDR_PREFIX}  0',        'Rename tab')           +
        blank() +
        note('Mirrors the WezTerm tab keys') +
        note('exactly: Alt+[ becomes') +
        note(f'{HERDR_PREFIX} [, Alt+1–9 becomes') +
        note(f'{HERDR_PREFIX} 1–9, and so on.') +
        blank() +
        note('Moving a tab has no herdr') +
        note('binding — WezTerm already owns') +
        note('Ctrl+Shift+←/→.')
)

_HERDR_WORKSPACES = (
    header('🐑 herdr — Workspaces') +
        sub('Switch') +
        row(f'{HERDR_PREFIX}  Ctrl+[',   'Previous workspace')   +
        row(f'{HERDR_PREFIX}  Ctrl+]',   'Next workspace')       +
        row(f'{HERDR_PREFIX}  Shift+W',  'Workspace picker')     +
        blank() +
        sub('Manage') +
        row(f'{HERDR_PREFIX}  Shift+N',  'New workspace')        +
        row(f'{HERDR_PREFIX}  Ctrl+0',   'Rename workspace')     +
        row(f'{HERDR_PREFIX}  Shift+D',  'Close workspace')      +
        row(f'{HERDR_PREFIX}  Shift+G',  'New git worktree')     +
        blank() +
        sub('Agents') +
        row(f'{HERDR_PREFIX}  b',        'Toggle sidebar')       +
        row(f'{HERDR_PREFIX}  Alt+1 – 9', 'Focus agent row')     +
        blank() +
        note('Background claude agents (cca)') +
        note('share one process, so the') +
        note('sidebar shows a single row for') +
        note('the whole fleet, not one each.')
)

_HERDR_SESSION = (
    header('🐑 herdr — Session Keys') +
        row(f'{HERDR_PREFIX}  ?',        'Help — all keybinds')  +
        row(f'{HERDR_PREFIX}  s',        'Settings')             +
        row(f'{HERDR_PREFIX}  g',        'Navigate mode')        +
        row(f'{HERDR_PREFIX}  q',        'Detach, keep running') +
        row(f'{HERDR_PREFIX}  Shift+R',  'Reload config')        +
        row(f'{HERDR_PREFIX}  o',        'Open notification')    +
        blank() +
        sub('Inside navigate mode') +
        row('h j k l',          'Move between panes')   +
        row('↑ / ↓',            'Switch workspace')     +
        row('1 – 9',            'Jump')                 +
        row('Esc',              'Leave navigate mode')  +
        blank() +
        note(f'{HERDR_PREFIX} ? is authoritative — it') +
        note('reads the live config, so it') +
        note('never drifts from this page.')
)

_HERDR_CLI = (
    header('🐑 herdr — CLI') +
        note('Every row below is prefixed') +
        note('with `herdr`.') +
        blank() +
        sub('Everyday') +
        row('(no args)',        'Launch or attach')     +
        row('--session <name>', 'Named session')        +
        row('session attach <n>', 'Attach by name')     +
        row('--remote <ssh>',   'Attach over SSH')      +
        row('status',           'Client + server state')+
        blank() +
        sub('Setup & docs') +
        row('completion zsh',   'Zsh completions')      +
        row('--skill',          'Print agent skill')    +
        row('--default-config', 'Dump full config')     +
        blank() +
        note('The server owns the PTYs and') +
        note('outlives the client: detaching') +
        note('or closing the window leaves') +
        note('agents running.')
)

_HERDR_SERVER = (
    header('🐑 herdr — Server & Config') +
        note('Every row below is prefixed') +
        note('with `herdr`.') +
        blank() +
        sub('Server') +
        row('server stop',      'Stop the server')      +
        row('server reload-config', 'Reload config.toml') +
        blank() +
        sub('Config') +
        row('config check',     'Validate + report')    +
        row('config reset-keys', 'Back up, drop keys')  +
        blank() +
        sub('Updates & extras') +
        row('update',           'Install latest')       +
        row('channel set <ch>', 'stable | preview')     +
        row('integration install', 'Claude Code hooks') +
        row('api <subcommand>', 'Socket API / state')   +
        blank() +
        note('Reload applies config.toml to a') +
        note('running server — same as') +
        note(f'{HERDR_PREFIX} Shift+R. A restart is') +
        note('only needed for shell changes.')
)

# ── Nightly version check ─────────────────────────────────────────────────────
# The home page answers "am I current, and what would I get if I upgraded?".
# `wezterm --version` prints "<build stamp>-<commit>", and that trailing commit
# is what makes the rest possible. Two API calls, because neither half of the
# answer is available on its own:
#
#   1. the rolling `nightly` release, for when the installer was last rebuilt.
#      The tag itself tells us nothing -- `published_at` is frozen in 2019 and
#      no asset name carries a version -- so the asset mtime is the only signal.
#   2. compare/<local commit>...main, for everything that landed since.
#
# Commits newer than that mtime are then dropped, so the changelog describes the
# build you would actually install rather than whatever is on main this second.
# Skipping that filter overstates the gap by a day or two of commits.
#
# All of it is best-effort. The check runs on a daemon thread so the pager opens
# instantly, the panels render from whatever state has arrived so far, and any
# failure falls back to the cached answer or a one-line reason. `--selftest`
# drives the states synthetically and never touches the network.
_API     = 'https://api.github.com/repos/wezterm/wezterm'
_ASSET   = 'WezTerm-nightly-setup.exe'
_TTL     = 6 * 3600        # the nightly rebuilds daily; 6h stays well inside
_TIMEOUT = 8

_HOME    = 0               # index of the home page in PAGES
_HOME_H  = 26              # the home panel is pinned to this many lines

# The compare URL is the widest thing on the page, and the panel rule is drawn
# to match it so the panel reads as one deliberate block rather than a
# 46-column panel with a URL hanging off the side. Written as the template it
# measures, since the sha is always abbreviated to 8.
_COMPARE = 'https://github.com/wezterm/wezterm/compare/{}...main'
_HOME_W  = len(_COMPARE.format('0' * 8))

# Mutated by the worker thread, read by the renderer. _GEN lets run() notice a
# result arrived without diffing the composed frame.
_VER      = {'state': 'checking'}
_VER_LOCK = threading.Lock()
_GEN      = [0]


def _ver_state():
    with _VER_LOCK:
        return dict(_VER)


_BUILD_RE = re.compile(r'(\d{8}-\d{6})-([0-9a-f]{7,40})')


def _version_candidates():
    """Binaries to ask for a version, best first.

    Not $WEZTERM_EXECUTABLE. That points at whichever binary owns the pane,
    and in a normal window it is wezterm-gui.exe -- which answers --version
    with "wezterm-gui someone forgot to call assign_version_info" and no
    version at all. Its directory is still the right place to look, because
    wezterm.exe sits beside it and reports properly; only under the mux server
    does $WEZTERM_EXECUTABLE happen to answer for itself.
    """
    exe = 'wezterm.exe' if os.name == 'nt' else 'wezterm'
    here = (os.environ.get('WEZTERM_EXECUTABLE_DIR')
            or os.path.dirname(os.environ.get('WEZTERM_EXECUTABLE') or ''))
    return ([os.path.join(here, exe)] if here else []) + ['wezterm']


def installed_build():
    """(build stamp, commit) of the installed wezterm, or (None, None)."""
    for cand in _version_candidates():
        try:
            out = subprocess.run([cand, '--version'], capture_output=True,
                                 text=True, timeout=_TIMEOUT)
        except (OSError, subprocess.SubprocessError):
            continue
        m = _BUILD_RE.search(out.stdout or '')
        if m:
            return m.group(1), m.group(2)
    return None, None


def _cache_file():
    base = (os.environ.get('XDG_CACHE_HOME')
            or os.environ.get('LOCALAPPDATA')
            or os.path.join(os.path.expanduser('~'), '.cache'))
    return os.path.join(base, 'wezterm-cheatsheet', 'nightly.json')


def _cache_read():
    try:
        with open(_cache_file(), encoding='utf-8') as fh:
            got = json.load(fh)
    except (OSError, ValueError):
        return None
    return got if isinstance(got, dict) and got.get('state') == 'ok' else None


def _cache_write(data):
    path = _cache_file()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as fh:
            json.dump(data, fh)
    except OSError:
        pass                  # a cache we cannot write is not worth failing over


def _api(path):
    req = urllib.request.Request(f'{_API}{path}', headers={
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'wezterm-cheatsheet',
    })
    with urllib.request.urlopen(req, timeout=_TIMEOUT) as resp:
        return json.load(resp)


def _fetch(commit):
    """Compare `commit` against the currently published nightly installer."""
    assets = _api('/releases/tags/nightly').get('assets') or []
    built = next((a.get('updated_at') for a in assets
                  if a.get('name') == _ASSET), None)
    diff = _api(f'/compare/{commit}...main')
    listed = diff.get('commits') or []
    # Both stamps are GitHub's own "...Z" ISO-8601, so they order as strings.
    # Only the shas are kept: the page links to the compare view rather than
    # reproducing the subjects, so there is no reason to cache them.
    shas = [c['sha'] for c in listed
            if not built or c['commit']['committer']['date'] <= built]
    return {
        'state':  'ok',
        'built':  built,
        'latest': shas[-1] if shas else commit,
        'behind': len(shas),
        # compare/ stops listing at 250 while total_commits keeps counting
        'capped': (diff.get('total_commits') or 0) > len(listed),
        'at':     time.time(),
    }


def _why(exc):
    """A reason short enough to sit in a 46-column panel."""
    code = getattr(exc, 'code', None)
    if code == 403:
        return 'github rate-limited us'
    if code == 404:
        return 'commit unknown to github'
    if code:
        return f'github returned HTTP {code}'
    return 'offline, or github unreachable'


def _check():
    build, commit = installed_build()
    if not commit:
        _publish({'state': 'error', 'msg': 'cannot read the local version'})
        return
    # The local build needs no network, so show it before going out to github
    # rather than leaving "Installed: unknown" on screen for the round trip.
    _publish({'state': 'checking', 'build': build, 'base': commit})
    cached = _cache_read()
    fresh = (cached and cached.get('base') == commit
             and time.time() - (cached.get('at') or 0) < _TTL)
    if fresh:
        _publish(dict(cached, build=build))
        return
    try:
        got = _fetch(commit)
    except Exception as exc:          # noqa: BLE001 -- URLError, HTTPError,
        # socket timeouts, malformed JSON and any future schema drift all land
        # here. A cheat sheet showing a stale version is fine; one that dies on
        # a flaky network is not.
        if cached and cached.get('base') == commit:
            _publish(dict(cached, build=build, stale=True))
        else:
            _publish({'state': 'error', 'msg': _why(exc),
                      'build': build, 'base': commit})
        return
    got['base'] = commit
    _cache_write(got)
    _publish(dict(got, build=build))


def _publish(state):
    """Swap in a new home page. Called from the worker thread.

    Order matters: the panels go in, then their memoised bodies are dropped,
    and only then does _GEN move. run() watches _GEN, so by the time it sees a
    change both the panels and the cache are already consistent.
    """
    with _VER_LOCK:
        _VER.clear()
        _VER.update(state)
    PAGES[_HOME] = PAGES[_HOME][:2] + (_home_panels(),)
    for key in [k for k in _BODY_CACHE if k[0] == _HOME]:
        del _BODY_CACHE[key]
    _GEN[0] += 1


def start_check():
    """Kick the check off in the background. Never raises."""
    threading.Thread(target=_check, daemon=True).start()


def load_cached():
    """Synchronous, cache-only refresh, for the non-interactive dump."""
    cached = _cache_read()
    build, commit = installed_build()
    if cached and cached.get('base') == commit:
        stale = time.time() - (cached.get('at') or 0) >= _TTL
        _publish(dict(cached, build=build, stale=stale))
    elif commit:
        _publish({'state': 'error', 'msg': 'not checked yet',
                  'build': build, 'base': commit})


# ── Home page ─────────────────────────────────────────────────────────────────
def _stamp(build):
    """20260823-230148 -> 2026-08-23 23:01, to line up with the API's stamps."""
    if not build or len(build) < 13:
        return 'unknown'
    return f'{build[0:4]}-{build[4:6]}-{build[6:8]} {build[9:11]}:{build[11:13]}'


def _utc(iso):
    return f'{iso[0:10]} {iso[11:16]}' if iso and len(iso) >= 16 else 'unknown'


def _verdict(st):
    """The one line that answers the question, coloured by the answer."""
    state = st.get('state')
    if state == 'checking':
        return [f'  {DIM}checking github…{RST}']
    if state != 'ok':
        return [f'  {BLD}{DIM}✗ {trunc(st.get("msg") or "check failed", 44)}{RST}']
    behind = st.get('behind') or 0
    if not behind:
        return [f'  {BLD}{GRN}✔ up to date{RST}']
    plural = '' if behind == 1 else 's'
    return [f'  {BLD}{YLW}▲ {behind}{"+" if st.get("capped") else ""} '
            f'commit{plural} behind{RST}']


def _fix(lines):
    """Pin a home panel to exactly _HOME_H lines.

    The masthead is sized off the tallest page, so a page that grew when the
    check landed would pop the banner in and out. _HOME_H is chosen to stay
    under the tallest static page at every column count -- see --selftest.
    """
    return (lines + [''] * _HOME_H)[:_HOME_H]


def _ver_row(stamp, commit):
    """A build line, shaped like row() but kept out of the search index.

    Both values are dynamic, so indexing them would put whatever the check
    happened to return at import -- "unknown", an empty commit -- into INDEX.
    """
    return [f'  {BLD}{YLW}{stamp}{RST}{" " * max(22 - wlen(stamp), 1)}'
            f'{TXT}{commit}{RST}']


def _changelog_lines(st):
    """Where to read what landed, rather than a copy of it.

    The URL is written out in full, scheme and all, because that is what makes
    it clickable: the bare-URL rule in config/general.lua needs the `\\w+://`
    to fire, and a shortened host would just be text. It is the one line on the
    page allowed past COL_W -- the home page is a single panel, so there is no
    neighbouring column for it to run into. See _check_panel_widths().
    """
    if st.get('state') != 'ok' or not st.get('behind'):
        return []
    plural = '' if st.get('behind') == 1 else 's'
    count = f'{st.get("behind")}{"+" if st.get("capped") else ""}'
    url = _COMPARE.format((st.get('base') or '')[:8])
    return (
        sub(f'Changelog · {count} commit{plural}') +
        [f'  {UND}{BLU}{url}{RST}'] +
        blank()
    )


def _status_panel(st):
    stale = st.get('stale') and st.get('state') == 'ok'
    return (
        header('📦 Nightly Build', _HOME_W) +
        _verdict(st) +
        ([f'  {DIM}(from cache — may be out of date){RST}'] if stale else []) +
        blank() +
        sub('Installed') +
        _ver_row(_stamp(st.get('build')), (st.get('base') or '')[:8]) +
        blank() +
        sub('Latest nightly') +
        _ver_row(_utc(st.get('built')), (st.get('latest') or '')[:8]) +
        blank() +
        _changelog_lines(st) +
        sub('Upgrade') +
        # Whole path as the key, empty description: row() would otherwise pad
        # the key column and split "scripts/" from the filename.
        row('scripts/wezterm-upgrade.sh', '') +
        blank() +
        note('Downloads the installer, checks it') +
        note('against the .sha256 published beside') +
        note('it, and tells you when to close') +
        note('WezTerm. --install runs it for you.') +
        blank() +
        note('winget cannot upgrade the nightly: the') +
        note('rolling tag leaves its recorded hash') +
        note('stale, so the upgrade always fails the') +
        note('hash check.')
    )


def _home_panels():
    return [_fix(_status_panel(_ver_state()))]


# ── Pages ─────────────────────────────────────────────────────────────────────
# (group, tab label, panels). One page is one screen. Groups are only a label
# on the tab strip -- navigation is flat, 1..N.
#
# Pages are capped at three panels so a page is a single row at 3 AND 4 columns.
# A fourth wraps below 209 columns and forces scrolling. `--selftest` guards
# this, since the repo has no test runner.
#
# Home is index 0 (_HOME) and is the only page rebuilt after import: _publish()
# swaps its panels in as the version check advances. Its panel titles must stay
# constant across every state, because INDEX joins rows to pages by title.
PAGES = [
    ('WEZTERM', 'Home',      _home_panels()),
    ('WEZTERM', 'Core',      [_QUICK_ACTIONS, _TABS, _PANES]),
    ('WEZTERM', 'Workspace', [_WORKSPACES, _SESSIONS, _MUX]),
    ('WEZTERM', 'Editing',   [_CURSOR, _COPY_MODE, _SCROLLING]),
    ('WEZTERM', 'Look',      [_BACKGROUND, _WINDOW, _ADV_MODES]),
    ('WEZTERM', 'CLI',       [_WEZ_CLI_PANES, _WEZ_CLI_QUERY, _WEZ_CLI_TOP]),
    ('HERDR',   'Keys',      [_HERDR_PANES, _HERDR_TABS, _HERDR_WORKSPACES]),
    ('HERDR',   'CLI',       [_HERDR_SESSION, _HERDR_CLI, _HERDR_SERVER]),
    ('SHELL',   'Zsh',       [_ZSH_FUZZY, _ZSH_GLOB, _ZSH_SHELL]),
    ('SHELL',   'Prompt',    [_PROMPT]),
    ('CLI',     'Tools',     [_FILE_TOOLS, _VIEWERS, _LAZY_TOOLS]),
    ('CLI',     'Atuin',     [_ATUIN_SEARCH, _ATUIN_FILTER, _ATUIN_CLI]),
    ('CLI',     'Yazi',      [_YAZI_NAV, _YAZI_OPS, _YAZI_MISC]),
]

# ── Search index ──────────────────────────────────────────────────────────────
# Flattened (page, panel, key, desc) for every row on every page. Built once at
# import from the pairs row() recorded, joined to PAGES via the panel title.
def _build_index():
    page_of = {}
    for i, (_, _, panels) in enumerate(PAGES):
        for panel in panels:
            page_of[ANSI.sub('', panel[0]).strip()] = i
    missing = {p for p, _, _, _ in _ROWS} - set(page_of)
    if missing:                       # a panel was defined but never placed
        raise AssertionError(f'panels missing from PAGES: {sorted(missing)}')
    return [(page_of[panel], panel, sub_, key, desc)
            for panel, sub_, key, desc in _ROWS]


def _build_panel_text():
    """Full text of each panel, for the fallback pass. Keyed by (page, panel)."""
    out = {}
    for page, panel, sub_, key, desc in INDEX:
        blob = out.setdefault((page, panel), [PAGES[page][1], panel])
        blob += [sub_ or '', key, desc]
    for (page, panel), blob in out.items():
        blob += _NOTES.get(panel, [])
    return {k: ' '.join(v).lower() for k, v in out.items()}


INDEX = _build_index()
PANEL_TEXT = _build_panel_text()
_RECORD[0] = False        # import pass over; later home rebuilds must not record


def search(query):
    """Rows matching every token. Falls back to whole panels via their notes.

    A fallback hit has key None: the words matched only running prose (tool
    names like "carapace" that never appear as a key), so the useful answer is
    "this section talks about it" rather than any single row.
    """
    tokens = query.lower().split()
    if not tokens:
        return []
    hits = []
    for entry in INDEX:
        page, panel, sub_, key, desc = entry
        hay = f'{PAGES[page][1]} {panel} {sub_ or ""} {key} {desc}'.lower()
        if not all(t in hay for t in tokens):
            continue
        # Rank by where the match landed, so a row that merely inherited a
        # matching sub-heading sorts below one that names the thing outright.
        k, d = key.lower(), desc.lower()
        if all(t in k for t in tokens):
            rank = 0
        elif all(t in d for t in tokens):
            rank = 1
        elif all(t in f'{k} {d}' for t in tokens):
            rank = 2
        elif all(t in (sub_ or '').lower() for t in tokens):
            rank = 3
        else:
            rank = 4
        hits.append((rank, entry))
    if hits:
        hits.sort(key=lambda h: h[0])          # stable: page order within a rank
        return [e for _, e in hits]
    return [(page, panel, None, None, 'mentioned in this section')
            for (page, panel), text in PANEL_TEXT.items()
            if all(t in text for t in tokens)]


def highlight(text, tokens, base):
    """Re-colour every token occurrence in `text`, restoring `base` after each."""
    if not tokens:
        return f'{base}{text}{RST}'
    spans = []
    low = text.lower()
    for t in tokens:
        start = low.find(t)
        while start != -1:
            spans.append((start, start + len(t)))
            start = low.find(t, start + 1)
    if not spans:
        return f'{base}{text}{RST}'
    spans.sort()
    merged = [list(spans[0])]
    for s, e in spans[1:]:
        if s <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], e)
        else:
            merged.append([s, e])
    out, pos = [], 0
    for s, e in merged:
        out.append(f'{base}{text[pos:s]}{RST}')
        out.append(f'{BLD}{GRN}{text[s:e]}{RST}')
        pos = e
    out.append(f'{base}{text[pos:]}{RST}')
    return ''.join(out)


def pad(text, width):
    """Pad to `width` display columns, ignoring ANSI."""
    return text + ' ' * max(0, width - wlen(text))


BANNER = [
    '██╗    ██╗███████╗███████╗████████╗███████╗██████╗ ███╗   ███╗',
    '██║    ██║██╔════╝╚══███╔╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║',
    '██║ █╗ ██║█████╗    ███╔╝    ██║   █████╗  ██████╔╝██╔████╔██║',
    '██║███╗██║██╔══╝   ███╔╝     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║',
    '╚███╔███╔╝███████╗███████╗   ██║   ███████╗██║  ██║██║ ╚═╝ ██║',
    ' ╚══╝╚══╝ ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝',
]


_BODY_CACHE = {}


def page_body(idx, cols):
    """Compose one page's panels into lines, chunked into rows of `cols`.

    Memoised: every redraw measures all pages to place the banner, and search
    redraws on each keystroke.
    """
    key = (idx, cols)
    if key in _BODY_CACHE:
        return _BODY_CACHE[key]
    panels = PAGES[idx][2]
    out = []
    for i in range(0, len(panels), cols):
        if out:
            out.append('')
        out.extend(compose_cols(panels[i:i + cols]))
    _BODY_CACHE[key] = out
    return out


def tab_strip(active, width):
    """Group-labelled tab strip, or a compact indicator when it will not fit."""
    parts, plain, last_group = [], [], None
    for i, (group, label, _) in enumerate(PAGES):
        if group != last_group:
            if last_group is not None:
                parts.append(f'{DIM}  ·  {RST}')
                plain.append('  ·  ')
            parts.append(f'{BLD}{CYN}{group}{RST} ')
            plain.append(f'{group} ')
            last_group = group
        if i == active:
            parts.append(f'{BLD}{YLW} {i + 1} {label} {RST}')
        else:
            parts.append(f'{DIM} {i + 1} {label} {RST}')
        plain.append(f' {i + 1} {label} ')
    if wlen(''.join(plain)) + 4 <= width:
        return '  ' + ''.join(parts)
    group, label, _ = PAGES[active]
    return (f'  {DIM}‹{RST} {BLD}{CYN}{group}{RST} {BLD}{YLW}{label}{RST} '
            f'{DIM}›  {active + 1}/{len(PAGES)}{RST}')


def _masthead(size, cols):
    """Leading blank line plus the banner, or a one-line wordmark when short.

    Driven by terminal height alone -- never by the current page -- so it does
    not pop in and out as you cycle tabs or start a search.
    """
    tallest = max(len(page_body(i, cols)) for i in range(len(PAGES)))
    if size.lines >= tallest + len(BANNER) + 8 and size.columns >= 66:
        return [''] + [f'  {BLD}{BLU}{line}{RST}' for line in BANNER] + ['']
    return ['', f'  {BLD}{BLU}WEZTERM{RST}  {DIM}cheat sheet{RST}']


def _fit(head, body, hints, size, scroll):
    """Pad or window `body` so head+body+foot is exactly `size.lines` tall."""
    view_h = max(1, size.lines - len(head) - 2)
    max_scroll = max(0, len(body) - view_h)
    scroll = max(0, min(scroll, max_scroll))
    view = body[scroll:scroll + view_h]
    view += [''] * (view_h - len(view))
    if max_scroll:
        hints = f'↑/↓ scroll ({scroll}/{max_scroll})  ·  ' + hints
    return head + view + ['', f'  {DIM}{hints}{RST}'], scroll


def frame(active, scroll, size):
    """Build the full screen as a list of lines, plus the clamped scroll offset."""
    cols = num_cols(size.columns)
    head = _masthead(size, cols) + [tab_strip(active, size.columns), '']
    # Jumping reads one keypress, so it only ever reaches page 9 however many
    # pages there are. Claim what actually works.
    hints = (f'←/→ page  ·  1-{min(9, len(PAGES))} jump  ·  '
             f'/ search  ·  q quit')
    return _fit(head, page_body(active, cols), hints, size, scroll)


def search_body(results, tokens, sel, width):
    """One line per hit: page · panel · key · description."""
    show_panel = width >= 132
    w_page, w_panel, w_key = 11, 30, 22
    w_desc = width - 4 - w_page - w_key - (w_panel if show_panel else 0)
    out = []
    for i, (page, panel, _sub, key, desc) in enumerate(results):
        mark = f'{BLD}{YLW}▸ {RST}' if i == sel else '  '
        base = TXT if i == sel else DIM
        line = mark + pad(highlight(PAGES[page][1], tokens, CYN), w_page)
        if show_panel:
            line += pad(highlight(trunc(panel, w_panel - 2), tokens, DIM), w_panel)
        if key is None:                     # panel-level fallback hit
            line += pad(f'{DIM}—{RST}', w_key)
            line += f'{DIM}{trunc(desc, w_desc)}{RST}'
        else:
            line += pad(highlight(trunc(key, w_key - 2), tokens, BLD + YLW), w_key)
            line += highlight(trunc(desc, w_desc), tokens, base)
        out.append(line)
    return out


def search_frame(query, results, sel, scroll, size):
    """The search view: prompt where the tab strip goes, hits in the body."""
    cols = num_cols(size.columns)
    tokens = query.lower().split()

    if not query:
        status = f'{DIM}type to search all {len(INDEX)} shortcuts{RST}'
    elif not results:
        status = f'{DIM}no matches{RST}'
    elif results[0][3] is None:
        status = f'{DIM}{len(results)} section{"s" if len(results) > 1 else ""} mention it{RST}'
    else:
        status = f'{DIM}{len(results)} match{"es" if len(results) > 1 else ""}{RST}'
    prompt = f'  {BLD}{GRN}/{RST} {TXT}{query}{RST}{BLD}{YLW}▌{RST}  {status}'

    head = _masthead(size, cols) + [prompt, '']
    body = search_body(results, tokens, sel, size.columns)
    hints = 'Enter  go to section  ·  ↑/↓ select  ·  Esc cancel'
    return _fit(head, body, hints, size, scroll)


# ── Input ─────────────────────────────────────────────────────────────────────
# Single-keypress reading. WezTerm on Windows runs children under ConPTY, which
# can deliver arrows either as console scan codes (msvcrt's \x00/\xe0 prefix) or
# as raw CSI escapes, so both forms are decoded.
_CSI  = {'A': 'UP', 'B': 'DOWN', 'C': 'RIGHT', 'D': 'LEFT', '5': 'PGUP', '6': 'PGDN'}
_SCAN = {'H': 'UP', 'P': 'DOWN', 'M': 'RIGHT', 'K': 'LEFT', 'I': 'PGUP', 'Q': 'PGDN'}

if os.name == 'nt':
    import time
    import msvcrt

    class Keys:
        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return False

        def poll(self, timeout):
            deadline = time.monotonic() + timeout
            while not msvcrt.kbhit():
                if time.monotonic() >= deadline:
                    return None
                time.sleep(0.02)
            ch = msvcrt.getwch()
            if ch in ('\x00', '\xe0'):
                return _SCAN.get(msvcrt.getwch(), '')
            if ch == '\x1b':
                time.sleep(0.02)          # let the rest of the sequence land
                if not msvcrt.kbhit():
                    return 'ESC'
                if msvcrt.getwch() != '[':
                    return 'ESC'
                code = msvcrt.getwch()
                if code in ('5', '6'):
                    msvcrt.getwch()       # swallow the trailing '~'
                return _CSI.get(code, '')
            return ch
else:
    import termios
    import tty
    import select

    class Keys:
        def __enter__(self):
            self.fd = sys.stdin.fileno()
            self.saved = termios.tcgetattr(self.fd)
            tty.setraw(self.fd)
            return self

        def __exit__(self, *exc):
            termios.tcsetattr(self.fd, termios.TCSADRAIN, self.saved)
            return False

        def _ready(self, timeout):
            return bool(select.select([sys.stdin], [], [], timeout)[0])

        def poll(self, timeout):
            if not self._ready(timeout):
                return None
            ch = sys.stdin.read(1)
            if ch == '\x1b':
                if not self._ready(0.02):
                    return 'ESC'
                if sys.stdin.read(1) != '[':
                    return 'ESC'
                code = sys.stdin.read(1)
                if code in ('5', '6'):
                    sys.stdin.read(1)
                return _CSI.get(code, '')
            return ch


# ── Drivers ───────────────────────────────────────────────────────────────────
def dump():
    """Non-interactive fallback: every page, top to bottom.

    Cache-only: a dump piped into a pager or a diff must not stall on the
    network. `--selftest` is what actually pins the layout down.
    """
    load_cached()
    cols = num_cols(shutil.get_terminal_size((160, 40)).columns)
    for i, (group, label, _) in enumerate(PAGES):
        print(f'\n  {BLD}{BLU}{"═" * 60}{RST}')
        print(f'  {BLD}{BLU}  {group}  ·  {label}{RST}')
        print(f'  {BLD}{BLU}{"═" * 60}{RST}\n')
        for line in page_body(i, cols):
            print(line)
    print()


_SEQ = re.compile(r'\x1b\[([0-9;]*)([A-Za-z])')


def _screen_width(line):
    """True rightmost column of a composed line, honouring CSI-G column jumps."""
    col, rightmost, pos = 1, 0, 0
    while pos < len(line):
        m = _SEQ.match(line, pos)
        if m:
            if m.group(2) == 'G':
                col = int(m.group(1) or '1')
            pos = m.end()
            continue
        nxt = line.find('\x1b', pos)
        chunk = line[pos:] if nxt == -1 else line[pos:nxt]
        col += wlen(chunk)
        rightmost = max(rightmost, col - 1)
        pos += len(chunk)
    return rightmost


# Synthetic version-check results, so --selftest covers every home-page state
# without a network call.
_DEMO = [
    # _check() publishes up to three times: before it knows anything, once the
    # local build is read, then the result. All three render.
    ('opening',  {'state': 'checking'}),
    ('probed',   {'state': 'checking', 'build': '20260823-230148',
                  'base': 'f93d9035'}),
    ('error',    {'state': 'error', 'msg': 'offline, or github unreachable',
                  'build': '20260823-230148', 'base': 'f93d9035'}),
    ('noversion', {'state': 'error', 'msg': 'cannot read the local version'}),
    ('current',  {'state': 'ok', 'build': '20260921-040521', 'base': 'b09b56c2',
                  'built': '2026-09-21T04:05:21Z', 'latest': 'b09b56c2',
                  'behind': 0, 'capped': False}),
    ('behind',   {'state': 'ok', 'build': '20260823-230148', 'base': 'f93d9035',
                  'built': '2026-09-21T04:05:21Z', 'latest': 'b09b56c2',
                  'behind': 40, 'capped': False}),
    ('one',      {'state': 'ok', 'build': '20260823-230148', 'base': 'f93d9035',
                  'built': '2026-09-21T04:05:21Z', 'latest': 'b09b56c2',
                  'behind': 1, 'capped': False}),
    ('stale',    {'state': 'ok', 'build': '20260823-230148', 'base': 'f93d9035',
                  'built': '2026-09-21T04:05:21Z', 'latest': 'b09b56c2',
                  'behind': 2, 'capped': False, 'stale': True}),
    ('capped',   {'state': 'ok', 'build': '20260101-000000', 'base': 'deadbeef',
                  'built': '2026-09-21T04:05:21Z', 'latest': 'b09b56c2',
                  'behind': 250, 'capped': True}),
]


def _check_frames(label, pages, sizes, bad):
    """Assert every frame in `pages` exactly fills the screen and fits it."""
    import types
    for w, h in sizes:
        size = types.SimpleNamespace(columns=w, lines=h)
        for i in pages:
            lines, _ = frame(i, 0, size)
            if len(lines) != h:
                print(f'  FAIL {label} {w}x{h} page {i + 1}: '
                      f'{len(lines)} lines, want {h}')
                bad += 1
            for n, ln in enumerate(lines):
                if _screen_width(ln) > w:
                    print(f'  FAIL {label} {w}x{h} page {i + 1} line {n}: '
                          f'{_screen_width(ln)} cols, want <= {w}')
                    bad += 1
                    break
    return bad


def _check_panel_widths(bad):
    """Assert no panel overruns its own column, on every multi-panel page.

    Composed lines jump columns with CSI G, so a panel that runs past its 48
    columns is invisible to _screen_width -- it silently overwrites the next
    separator instead of making the line longer. Measure before composing.

    Pages with a single panel are exempt, because there is no next column to
    overwrite: compose_cols() emits the panel alone, with no CSI G at all. The
    only bound there is the terminal itself, which _check_frames already
    enforces at every size down to 80 columns. That is what lets the home page
    print a full clickable URL.
    """
    for _, label, panels in PAGES:
        if len(panels) < 2:
            continue
        for panel in panels:
            for n, ln in enumerate(panel):
                if wlen(ln) > COL_W + 2:
                    print(f'  FAIL panel width {label} line {n}: '
                          f'{wlen(ln)} cols, want <= {COL_W + 2}: {ANSI.sub("", ln)!r}')
                    bad += 1
                    break
    return bad


def selftest():
    """Check the layout invariants the panel content is easy to break."""
    import types
    bad = 0
    sizes = ((230, 62), (209, 60), (208, 50), (156, 40), (120, 30), (80, 20))

    # The home page is rebuilt at runtime, so each state it can reach has to
    # obey the same contract as the static pages.
    for name, st in _DEMO:
        _publish(st)
        for panel in PAGES[_HOME][2]:
            if len(panel) != _HOME_H:
                print(f'  FAIL home/{name}: panel is {len(panel)} lines, '
                      f'want _HOME_H={_HOME_H}')
                bad += 1
        # The masthead is sized off the tallest page. If home ever becomes the
        # tallest, the banner starts popping in and out as the check lands.
        for cols in (1, 2, 3, 4):
            home = len(page_body(_HOME, cols))
            other = max(len(page_body(i, cols)) for i in range(1, len(PAGES)))
            if home > other:
                print(f'  FAIL home/{name}: cols={cols} home is {home} lines, '
                      f'taller than the tallest static page ({other})')
                bad += 1
        was = bad
        bad = _check_frames(f'home/{name}', [_HOME], sizes, bad)
        bad = _check_panel_widths(bad)
        print(f'  home/{name:8s}  {"ok" if bad == was else "FAILED"}')

    _publish(dict(dict(_DEMO)['behind']))   # a realistic state for the sweep
    for w, h in sizes:
        size = types.SimpleNamespace(columns=w, lines=h)
        cols = num_cols(w)
        tallest = max(len(page_body(i, cols)) for i in range(len(PAGES)))
        # the search view must obey the same height/width contract
        for q in ('', 'a', 'split pane', 'carapace', 'zzzz', 'e' * 60):
            hits = search(q)
            for s in (0, max(0, len(hits) - 1)):
                lines, _ = search_frame(q, hits, s, 0, size)
                if len(lines) != h:
                    print(f'  FAIL search {w}x{h} {q!r}: {len(lines)} lines, want {h}')
                    bad += 1
                for n, ln in enumerate(lines):
                    if _screen_width(ln) > w:
                        print(f'  FAIL search {w}x{h} {q!r} line {n}: '
                              f'{_screen_width(ln)} cols, want <= {w}')
                        bad += 1
                        break
        bad = _check_frames('page', range(len(PAGES)), ((w, h),), bad)
        print(f'  {w}x{h}  cols={cols}  tallest page={tallest} lines')
    print('FAILED' if bad else 'OK')
    return 1 if bad else 0


BKSP = ('\x08', '\x7f')


def run():
    active, scroll, last = _HOME, 0, None
    searching, query, sel, results = False, '', 0, []
    start_check()
    sys.stdout.write('\033[?1049h\033[?25l\033]0;WezTerm Cheat Sheet\007')
    try:
        with Keys() as keys:
            while True:
                size = shutil.get_terminal_size((160, 40))
                # _GEN advances when the version check lands, which changes the
                # home page underneath us without any keypress.
                state = (active, scroll, size, searching, query, sel, _GEN[0])
                if state != last:
                    if searching:
                        lines, scroll = search_frame(query, results, sel, scroll, size)
                    else:
                        lines, scroll = frame(active, scroll, size)
                    sys.stdout.write('\033[H' + '\r\n'.join(
                        '\033[2K' + ln for ln in lines) + '\033[J')
                    sys.stdout.flush()
                    last = (active, scroll, size, searching, query, sel, _GEN[0])

                k = keys.poll(0.1)
                if k is None:
                    continue
                if k == '\x03':
                    return

                # ---- search mode: nearly every key is literal text ----------
                if searching:
                    if k == 'ESC':
                        searching, scroll = False, 0
                    elif k in ('\r', '\n'):
                        if results:
                            active = results[sel][0]
                        searching, scroll = False, 0
                    elif k in BKSP:
                        query = query[:-1]
                    elif k == '\x15':                      # Ctrl+U
                        query = ''
                    elif k == '\x17':                      # Ctrl+W
                        query = ' '.join(query.split()[:-1])
                    elif k == 'UP':
                        sel -= 1
                    elif k == 'DOWN':
                        sel += 1
                    elif k == 'PGUP':
                        sel -= 10
                    elif k == 'PGDN':
                        sel += 10
                    elif len(k) == 1 and k.isprintable():
                        query += k
                    else:
                        continue
                    results = search(query)
                    sel = max(0, min(sel, len(results) - 1)) if results else 0
                    # keep the selection inside the visible window
                    view_h = max(1, size.lines - len(_masthead(
                        size, num_cols(size.columns))) - 4)
                    if sel < scroll:
                        scroll = sel
                    elif sel >= scroll + view_h:
                        scroll = sel - view_h + 1
                    continue

                # ---- page mode ---------------------------------------------
                if k in ('q', 'Q', 'ESC'):
                    return
                if k == '/':
                    searching, query, sel, scroll = True, '', 0, 0
                    results = []
                elif k in ('RIGHT', 'l', '\t'):
                    active, scroll = (active + 1) % len(PAGES), 0
                elif k in ('LEFT', 'h'):
                    active, scroll = (active - 1) % len(PAGES), 0
                elif k in ('DOWN', 'j'):
                    scroll += 1
                elif k in ('UP', 'k'):
                    scroll -= 1
                elif k == 'PGDN':
                    scroll += 10
                elif k == 'PGUP':
                    scroll -= 10
                elif k == 'g':
                    scroll = 0
                elif k == 'G':
                    scroll = 10 ** 6
                elif k.isdigit() and 1 <= int(k) <= len(PAGES):
                    active, scroll = int(k) - 1, 0
    finally:
        sys.stdout.write('\033[?25h\033[?1049l')
        sys.stdout.flush()


if __name__ == '__main__':
    # Python picks the ANSI code page (cp1252 here) for stdout when it is not a
    # console -- a pipe or a redirect to a file. Every page is built from box
    # drawing characters and Nerd Font glyphs, none of which cp1252 can encode,
    # so the --all dump died with UnicodeEncodeError exactly when it is most
    # useful: piped into a pager or captured for a diff.
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    if '--selftest' in sys.argv:
        sys.exit(selftest())
    if '--all' in sys.argv or not sys.stdout.isatty() or not sys.stdin.isatty():
        dump()
    else:
        try:
            run()
        except KeyboardInterrupt:
            pass
