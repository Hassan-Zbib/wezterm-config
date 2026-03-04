# WezTerm Config — Windows Setup

A modular WezTerm configuration for Windows, built on top of [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config).

Themed with **Catppuccin Macchiato** throughout — terminal, prompt, and startup panel.

---

## Features

- **Background image carousel** (16 included) — toggle to solid dark background with `Alt+b`
- **Powerline Starship prompt** — git status, language versions, command duration
- **System info panel** on shell startup — uptime, CPU, memory, network
- **AI agent status bar** — live Claude Code working/waiting/idle indicator
- **Kitty keyboard protocol** — Shift+Enter for multi-line input
- **Yazi file manager** integrated with auto-cd on quit
- **Session persistence** — save and restore workspace layouts (F9/F10)
- **SSH host selector** — fuzzy-search `~/.ssh/config` hosts (F7)
- **WSL support** — open WSL tabs alongside Git Bash
- **Tab bar at bottom** with active key-table indicator in left status
- **CLI toolbox** — lazygit, eza, btop, glow, and UniGetUI pre-configured with aliases

---

## Prerequisites

Install all of the following before cloning.

| Tool | Install |
|------|---------|
| [WezTerm Nightly](https://wezfurlong.org/wezterm/nightlies.html) | Download `.exe` installer from site |
| [PowerShell 7](https://github.com/PowerShell/PowerShell) | `winget install Microsoft.PowerShell` |
| [Git for Windows](https://gitforwindows.org/) | `winget install Git.Git` |
| [JetBrainsMono Nerd Font](https://www.nerdfonts.com/) | `winget install DEVCOM.JetBrainsMonoNerdFont` |
| [Starship](https://starship.rs/) | `winget install Starship.Starship` |
| [Yazi](https://yazi-rs.github.io/) | `winget install sxyazi.yazi` |

> PowerShell 7 is required for the system info panel (it queries Windows APIs). Git for Windows provides the Git Bash shell used as the default.

### Optional CLI Tools

These tools are pre-configured with aliases in `.bashrc`. Install whichever you want:

| Tool | Install | Alias | Description |
|------|---------|-------|-------------|
| [Lazygit](https://github.com/jesseduffield/lazygit) | `winget install JesseDuffield.lazygit` | `lg` | Terminal UI for Git |
| [eza](https://github.com/eza-community/eza) | `winget install eza-community.eza` | `ls`, `ll`, `lt` | Modern `ls` with icons and tree view |
| [btop](https://github.com/aristocratos/btop4win) | `winget install aristocratos.btop4win` | `btop` | Interactive system monitor (CPU, RAM, disk, network) |
| [Glow](https://github.com/charmbracelet/glow) | `winget install charmbracelet.glow` | `glow` | Render Markdown files in the terminal |
| [UniGetUI](https://github.com/marticliment/UniGetUI) | `winget install MartiCliment.UniGetUI` | `pkgs` | GUI for managing winget/scoop/choco/pip/npm packages |

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/Hassan-Zbib/wezterm-config ~/Desktop/GitHub/wezterm-config
```

> If you clone to a different location, update `WEZTERM_CONFIG_DIR` in the next two steps.

### 2. Copy the home files

```bash
cp ~/Desktop/GitHub/wezterm-config/home/.wezterm.lua ~/.wezterm.lua
cp ~/Desktop/GitHub/wezterm-config/home/.bashrc ~/.bashrc
```

Both files have a single path variable at the top — **only change it if you cloned to a different location**:

**`~/.wezterm.lua`**
```lua
local WEZTERM_CONFIG_DIR = wezterm.home_dir .. '/Desktop/GitHub/wezterm-config'
```

**`~/.bashrc`**
```bash
WEZTERM_CONFIG_DIR="$HOME/Desktop/GitHub/wezterm-config"
```

### 3. Restart WezTerm

WezTerm auto-loads `~/.wezterm.lua` on startup. Open a new tab to see the system info panel appear.

---

## Repository Structure

```
wezterm-config/
├── home/
│   ├── .wezterm.lua        # Entry point — copy to ~/
│   └── .bashrc             # Git Bash config — copy to ~/
│
├── config/
│   ├── appearance.lua      # Opacity, tab bar, cursor, window frame
│   ├── bindings.lua        # All keyboard & mouse shortcuts
│   ├── domains.lua         # WSL domain definitions
│   ├── fonts.lua           # Font family and size
│   ├── general.lua         # Scrollback, kitty keyboard, hyperlinks, default cwd
│   └── launch.lua          # Default shell (Git Bash)
│
├── events/
│   ├── gui-startup.lua     # Window position on startup
│   ├── left-status.lua     # Leader key / key-table indicator
│   ├── right-status.lua    # Agent status, clock, battery
│   ├── tab-title.lua       # Tab title formatting
│   ├── new-tab-button.lua  # Custom new-tab button
│   └── window-title.lua    # Window title (active pane name)
│
├── utils/
│   ├── backdrops.lua       # Background image manager
│   ├── cells.lua           # Status bar segment builder
│   ├── gpu-adapter.lua     # GPU auto-selection for WebGPU
│   ├── math.lua            # Math helpers
│   ├── opts-validator.lua  # Config validation
│   ├── platform.lua        # OS detection
│   ├── sessions.lua        # Session save/restore
│   └── ssh-hosts.lua       # SSH config parser + selector
│
├── colors/
│   └── custom.lua          # Catppuccin Macchiato color overrides
│
├── backdrops/              # Background wallpaper images
│
├── scripts/
│   ├── cheatsheet.sh       # F1 keyboard shortcut reference (opens in new tab)
│   └── sysinfo.sh          # Startup system info panel
│
└── starship.toml           # Starship prompt configuration
```

---

## Keyboard Shortcuts

> **Windows key mapping:** `Super` = `Alt` · `Super+Rev` = `Alt+Ctrl`

Press `F1` to open the full cheat sheet inside WezTerm.

### Quick Actions

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `F1` | Cheat Sheet | `F11` | Fullscreen |
| `F2` | Command Palette | `F12` | Debug Overlay |
| `F3` | Launcher Menu | `F6` | Toggle Agent Notifications |
| `F4` | Fuzzy Tabs | `F7` | SSH Host Selector |
| `F5` | Fuzzy Workspaces | `F8` | Copy Mode |
| `F9` | Save Session | `F10` | Restore Session |
| `Alt+f` | Search | `Alt+Ctrl+u` | Open URL |
| `Ctrl+Shift+C` | Copy | `Ctrl+Shift+V` | Paste |
| `Right-click` | Copy / Paste | `Alt+Shift+V` | Paste image as file path |

### Cursor Movement

| Key | Action |
|-----|--------|
| `Alt+←` | Jump to line start |
| `Alt+→` | Jump to line end |
| `Shift+Enter` | New line without submitting |
| `Alt+Backspace` | Clear line (Git Bash only) |

### Tabs

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `Alt+t` | New Tab (Git Bash) | `Alt+[` | Previous Tab |
| `Alt+Ctrl+t` | New Tab (WSL) | `Alt+]` | Next Tab |
| `Alt+Ctrl+w` | Close Tab | `Alt+Ctrl+[` | Move Tab Left |
| `Alt+0` | Rename Tab | `Alt+Ctrl+]` | Move Tab Right |
| `Alt+Ctrl+0` | Undo Rename | `Alt+9` | Toggle Tab Bar |

### Panes

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `Alt+\` | Split Vertical | `Alt+Ctrl+↑` | Focus Up |
| `Alt+Ctrl+\` | Split Horizontal | `Alt+Ctrl+↓` | Focus Down |
| `Alt+w` | Close Pane | `Alt+Ctrl+←` | Focus Left |
| `Alt+Enter` | Zoom Pane | `Alt+Ctrl+→` | Focus Right |
| `Alt+Ctrl+p` | Swap Panes | | |

### Scrolling

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `Alt+u` | Scroll Up 5 lines | `Alt+d` | Scroll Down 5 lines |
| `Page Up` | Scroll Page Up | `Page Down` | Scroll Page Down |
| `End` | Scroll to Bottom | | |

### Background Images

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `Alt+/` | Random Image | `Alt+,` | Previous Image |
| `Alt+Ctrl+/` | Browse & Select | `Alt+.` | Next Image |
| `Alt+b` | Toggle Background On/Off | | |

### Font & Window

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `Alt+=` | Grow Window | `Alt+n` | New Window |
| `Alt+-` | Shrink Window | `Alt+Ctrl+Enter` | Maximize |

### File Manager (yazi)

| Key | Action |
|-----|--------|
| `Alt+e` | Open yazi (auto-cd to selected directory on quit) |

Inside yazi: `h` `j` `k` `l` navigate · `Space` select · `y` copy · `p` paste · `/` search · `q` quit

### Advanced Modes

**Leader key:** `Alt+Ctrl+Space`, then press:

| Key | Mode |
|-----|------|
| `f` | **Font Resize** — `↑`/`↓` to resize, `r` to reset, `Esc` to exit |
| `p` | **Pane Resize** — `↑`/`↓`/`←`/`→` to resize, `Esc` to exit |

---

## CLI Tools & Aliases

The `.bashrc` configures the following aliases:

| Alias | Command | Description |
|-------|---------|-------------|
| `ls` | `eza --icons` | List files with icons |
| `ll` | `eza --icons -la` | Long list with hidden files |
| `lt` | `eza --icons --tree --level=2` | Tree view (2 levels) |
| `lg` | `lazygit` | Terminal UI for Git |
| `btop` | `btop4win` | Interactive system monitor |
| `pkgs` | UniGetUI | GUI package manager |
| `glow` | `glow` | Markdown viewer/browser |
| `yy` | yazi with auto-cd | File manager (cd to dir on quit) |

### Lazygit Quick Reference

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| `Space` | Stage/unstage file | `c` | Commit |
| `P` | Push | `p` | Pull |
| `Enter` | Expand file / view diff | `[ / ]` | Switch panels |
| `/` | Filter list | `?` | Keybindings help |
| `x` | Open actions menu | `+` | Next screen mode |
| `s` | Stash changes | `S` | View stash entries |
| `n` | New branch | `r` | Rebase options |
| `M` | Merge into current | `z` | Undo (via reflog) |
| `q` | Quit | | |

---

## Startup System Info Panel

When opening a new WezTerm pane, a system info panel is displayed:

```
  +──────────────────────────────────────
  |  user      Hasan@DESKTOP
  |  uptime    5h, 30m
  |  term      WezTerm
  |  shell     bash 5.2.21
  |  cpu       12%
  |  memory    8.2G / 16.1G
  |  swap      0.5G / 8.0G
  |  network   192.168.1.100/24
  +──────────────────────────────────────
```

- Only appears in **WezTerm** (gated on `$WEZTERM_PANE`)
- Data is fetched via a single PowerShell call (requires PowerShell 7)
- **AWS row** only appears when `AWS_PROFILE` or `AWS_REGION` is set

---

## Status Bar

**Left status** — shows the active key-table name or a leader key indicator when pressed. Shows `F1:help` hint otherwise.

**Right status** — powered by [wezterm-agent-deck](https://github.com/Eric162/wezterm-agent-deck):
- AI agent activity counts (working / waiting / idle)
- 12-hour clock
- Battery level

---

## Starship Prompt

The prompt uses the Catppuccin Macchiato powerline preset, showing:

- OS icon + username
- Current directory
- Git branch + status
- Active language versions (Node, Python, Rust, Go, etc.)
- AWS profile + region (when active)
- Kubernetes context + namespace (when active)
- Terraform version + workspace (when in a TF directory)
- Command duration (for commands that take a while)

Config lives at `starship.toml` in the repo root. `STARSHIP_CONFIG` is set automatically by `.bashrc`.

---

## Customization

### Repo location

Both `~/.wezterm.lua` and `~/.bashrc` have a single `WEZTERM_CONFIG_DIR` variable at the top. Change it if you clone to a different path.

### Default working directory

New windows and tabs open in `~/Desktop/GitHub` by default. Change in `config/general.lua`:
```lua
default_cwd = wezterm.home_dir .. '/Desktop/GitHub'
```

### Window opacity

In `config/appearance.lua`:
```lua
window_background_opacity = 0.85  -- slight depth effect; 1.0 = fully opaque
```

### Background images

Add `.jpg`, `.png`, or `.gif` files to the `backdrops/` folder. They are auto-loaded on next WezTerm start. Use `Alt+/` to cycle randomly or `Alt+Ctrl+/` to browse.

### Default shell

In `config/launch.lua`:
```lua
-- Git Bash (default)
options.default_prog = { 'C:\\Program Files\\Git\\bin\\bash.exe', '--login' }

-- PowerShell 7
options.default_prog = { 'pwsh.exe', '-NoLogo' }
```

### Font

In `config/fonts.lua`:
```lua
font = wezterm.font({ family = 'JetBrainsMono Nerd Font', weight = 'Bold' })
font_size = 11.0
```

### WSL

In `config/domains.lua`, update the distribution name to match your installed WSL distro (run `wsl -l` to list available distros).

---

## Credits

- Base config: [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config)
- Theme: [Catppuccin](https://github.com/catppuccin/catppuccin)
- Agent status bar: [wezterm-agent-deck](https://github.com/Eric162/wezterm-agent-deck)
- Prompt: [Starship](https://starship.rs/)
- File manager: [Yazi](https://yazi-rs.github.io/)
- Git TUI: [Lazygit](https://github.com/jesseduffield/lazygit)
- Modern ls: [eza](https://github.com/eza-community/eza)
- System monitor: [btop4win](https://github.com/aristocratos/btop4win)
- Markdown viewer: [Glow](https://github.com/charmbracelet/glow)
- Package manager GUI: [UniGetUI](https://github.com/marticliment/UniGetUI)
