<h2 align="center">My WezTerm Config</h2>

<p align="center">
  <a href="https://github.com/Hassan-Zbib/wezterm-config">
    <img alt="Private Repo" src="https://img.shields.io/badge/repo-private-red?style=for-the-badge&logo=github&labelColor=302D41">
  </a>
</p>

![screenshot](./.github/screenshots/wezterm.gif)

> **Note:** This is a customized fork of [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config)

---

## 🪟 Full Setup Guide (Windows)

### Step 1 — Install Requirements

| Tool | Purpose | Install |
| ---- | ------- | ------- |
| **WezTerm Nightly** | Terminal emulator | [Download](https://github.com/wezterm/wezterm/releases/tag/nightly) |
| **PowerShell 7** | Shell for Claude Code | [Download](https://github.com/PowerShell/PowerShell/releases/latest) |
| **Git for Windows** | Git Bash shell | [Download](https://git-scm.com/download/win) |
| **JetBrainsMono Nerd Font** | Required font for icons | [Download](https://www.nerdfonts.com/font-downloads) |
| **Starship** | Cross-shell prompt | See below |
| **yazi** | TUI file manager | See below |

**Install Starship:**
```sh
winget install Starship.Starship
```

**Install yazi:**
```sh
winget install sxyazi.yazi
```

---

### Step 2 — Clone This Repo

Clone to any directory you prefer. The path you choose will be used in all config files.

```sh
git clone https://github.com/Hassan-Zbib/wezterm-config.git C:\path\to\your\wezterm-config
```

> Example: `C:\Users\YOUR-USERNAME\Desktop\GitHub\wezterm-config`

---

### Step 3 — Set Up `.wezterm.lua`

Create `C:\Users\YOUR-USERNAME\.wezterm.lua` and set the repo path:

```lua
local wezterm = require('wezterm')

-- *** SET THIS TO WHERE YOU CLONED THE REPO ***
local config_path = wezterm.home_dir .. '/Desktop/GitHub/wezterm-config'

package.path = package.path .. ';' .. config_path .. '/?.lua'
package.path = package.path .. ';' .. config_path .. '/?/init.lua'

local Config = require('config')
local agent_deck = wezterm.plugin.require('https://github.com/Eric162/wezterm-agent-deck')

require('utils.backdrops')
   :set_images_dir(config_path .. '/backdrops/')
   :set_images()
   :random()

require('events.left-status').setup()
require('events.right-status').setup()
require('events.tab-title').setup({ hide_active_tab_unseen = false, unseen_icon = 'numbered_box' })
require('events.new-tab-button').setup()
require('events.gui-startup').setup()
require('events.window-title').setup()

local config = Config:init()
   :append(require('config.appearance'))
   :append(require('config.bindings'))
   :append(require('config.domains'))
   :append(require('config.fonts'))
   :append(require('config.general'))
   :append(require('config.launch')).options

agent_deck.apply_to_config(config, {
   right_status = { enabled = false },
   notifications = { enabled = false },
})

return config
```

---

### Step 4 — Set Up Git Bash (`~/.bashrc`)

Create `C:\Users\YOUR-USERNAME\.bashrc` and set the repo path:

```bash
# ============================================================
# Git Bash Configuration
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

# ---- Starship Prompt ----
# *** SET THIS TO WHERE YOU CLONED THE REPO ***
export STARSHIP_CONFIG="$HOME/Desktop/GitHub/wezterm-config/starship.toml"
eval "$(starship init bash)"

# Append WezTerm cwd tracking after starship sets up PROMPT_COMMAND
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__wezterm_set_cwd"

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
```

---

### Step 5 — Verify

Restart WezTerm. You should see:
- Starship prompt with git branch and icons
- Tab title updating as you navigate directories
- `yy` command available for file browsing with auto-cd

---

### Changing the Repo Path (New Device)

If you clone the repo to a different location, update **two files**:

1. **`.wezterm.lua`** — change `config_path`:
   ```lua
   local config_path = wezterm.home_dir .. '/your/new/path/wezterm-config'
   ```

2. **`.bashrc`** — change `STARSHIP_CONFIG`:
   ```bash
   export STARSHIP_CONFIG="$HOME/your/new/path/wezterm-config/starship.toml"
   ```

---

### Configuration Files

| File | Purpose |
| ---- | ------- |
| `.wezterm.lua` | Entry point — set your repo path here |
| `starship.toml` | Starship prompt configuration |
| `config/appearance.lua` | Colors, opacity, cursor, tab bar |
| `config/fonts.lua` | Font family and size |
| `config/bindings.lua` | All keyboard shortcuts |
| `config/launch.lua` | Default shell and launch menu |
| `config/domains.lua` | WSL domain settings |
| `config/general.lua` | Scrollback, behavior settings |
| `backdrops/` | Background wallpaper images |

---

## ⌨️ Keyboard Shortcuts Cheat Sheet

> **Key Reference:**
> - `Alt` = `SUPER` in original config
> - `Alt+Ctrl` = `SUPER_REV` in original config
> - `Leader` = `Alt+Ctrl+Space`

### 🎯 Quick Actions
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>F1</kbd> | Copy Mode | <kbd>F11</kbd> | Fullscreen |
| <kbd>F2</kbd> | Command Palette | <kbd>F12</kbd> | Debug Overlay |
| <kbd>F3</kbd> | Launcher Menu | <kbd>Alt</kbd>+<kbd>f</kbd> | Search |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd> | Copy | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>u</kbd> | Open URL |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd> | Paste | Right-click | Copy selection / Paste |

### ✏️ Cursor Movement
| Keys | Action |
| ---- | ------ |
| <kbd>Alt</kbd>+<kbd>←</kbd> | Jump to Line Start |
| <kbd>Alt</kbd>+<kbd>→</kbd> | Jump to Line End |
| <kbd>Alt</kbd>+<kbd>Backspace</kbd> | Clear Line *(Git Bash only)* |

### 📑 Tabs
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>Alt</kbd>+<kbd>t</kbd> | New Tab | <kbd>Alt</kbd>+<kbd>[</kbd> | Previous Tab |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>t</kbd> | New Tab (WSL) | <kbd>Alt</kbd>+<kbd>]</kbd> | Next Tab |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>w</kbd> | Close Tab | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>[</kbd> | Move Tab Left |
| <kbd>Alt</kbd>+<kbd>0</kbd> | Rename Tab | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>]</kbd> | Move Tab Right |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>0</kbd> | Undo Rename | <kbd>Alt</kbd>+<kbd>9</kbd> | Toggle Tab Bar |

### 🪟 Panes
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>Alt</kbd>+<kbd>\\</kbd> | Split Vertical | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>k</kbd> | Focus Up |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>\\</kbd> | Split Horizontal | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>j</kbd> | Focus Down |
| <kbd>Alt</kbd>+<kbd>w</kbd> | Close Pane | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>h</kbd> | Focus Left |
| <kbd>Alt</kbd>+<kbd>Enter</kbd> | Zoom Pane | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>l</kbd> | Focus Right |
| | | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>p</kbd> | Swap Panes |

### 🖼️ Background Images
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>Alt</kbd>+<kbd>/</kbd> | Random Image | <kbd>Alt</kbd>+<kbd>,</kbd> | Previous Image |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>/</kbd> | Browse Images | <kbd>Alt</kbd>+<kbd>.</kbd> | Next Image |
| <kbd>Alt</kbd>+<kbd>b</kbd> | Toggle Background | | |

### 🔤 Font & Window
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>Alt</kbd>+<kbd>=</kbd> | Grow Window | <kbd>Alt</kbd>+<kbd>n</kbd> | New Window |
| <kbd>Alt</kbd>+<kbd>-</kbd> | Shrink Window | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>Enter</kbd> | Maximize |

### 📜 Scrolling
| Keys | Action |
| ---- | ------ |
| <kbd>Alt</kbd>+<kbd>u</kbd> | Scroll Up (5 lines) |
| <kbd>Alt</kbd>+<kbd>d</kbd> | Scroll Down (5 lines) |
| <kbd>Page Up</kbd> / <kbd>Page Down</kbd> | Scroll Page |
| <kbd>End</kbd> | Scroll to Bottom |

### 📁 File Manager (yazi)
| Keys | Action |
| ---- | ------ |
| <kbd>Alt</kbd>+<kbd>e</kbd> | Open yazi in current pane (auto-cd on quit) |

**Inside yazi:**
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>↑</kbd> / <kbd>↓</kbd> or <kbd>k</kbd> / <kbd>j</kbd> | Navigate | <kbd>Enter</kbd> | Open file/folder |
| <kbd>←</kbd> or <kbd>h</kbd> | Go up a folder | <kbd>→</kbd> or <kbd>l</kbd> | Enter folder |
| <kbd>Space</kbd> | Select file | <kbd>y</kbd> | Copy selected |
| <kbd>x</kbd> | Cut selected | <kbd>p</kbd> | Paste |
| <kbd>d</kbd> | Move to trash | <kbd>D</kbd> | Delete permanently |
| <kbd>/</kbd> | Search | <kbd>.</kbd> | Toggle hidden files |
| <kbd>q</kbd> | Quit + cd to current dir | <kbd>~</kbd> | Go to home |

### ⚙️ Advanced Modes
**Leader Key:** <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>Space</kbd>, then:
- <kbd>f</kbd> → Font Resize Mode (<kbd>k</kbd>/<kbd>j</kbd> to resize, <kbd>r</kbd> to reset, <kbd>Esc</kbd> to exit)
- <kbd>p</kbd> → Pane Resize Mode (<kbd>h</kbd>/<kbd>j</kbd>/<kbd>k</kbd>/<kbd>l</kbd> to resize, <kbd>Esc</kbd> to exit)

---

## 🎨 Customization

### Change Background Opacity
Edit `config/appearance.lua`:
```lua
window_background_opacity = 0.85  -- 0.0 = fully transparent, 1.0 = opaque
```

### Add Background Images
Drop image files into the `backdrops/` folder (jpg, png, gif supported).

### Change Default Shell
Edit `config/launch.lua`:
```lua
options.default_prog = { 'pwsh', '-NoLogo' }         -- PowerShell 7
options.default_prog = { 'wsl.exe', '-d', 'Ubuntu' } -- WSL Ubuntu
```

### Customize Starship Prompt
Edit `starship.toml` in the root of this repo. Full reference: https://starship.rs/config/

### Modify Colors
Edit `colors/custom.lua` to change the color scheme.

---

## 🔧 Features

### Agent Status Bar
Shows Claude Code / AI agent status in the right status bar:
- 🟢 `N working` — agent is processing
- 🟡 `N waiting` — agent needs input
- `N idle` — agent is ready

Powered by [wezterm-agent-deck](https://github.com/Eric162/wezterm-agent-deck).

### Background Image Selector
- Cycle through wallpapers with keybindings
- Fuzzy search for a specific image (Alt+Ctrl+/)
- Toggle background off for focus mode (Alt+b)

### Starship Prompt
Cross-shell prompt showing:
- Current directory (truncated)
- Git branch and status (modified, staged, ahead/behind)
- Active language version (Node, Python, Rust, Go)
- Command duration for slow commands (>2s)

Config file: `starship.toml`

### WezTerm Shell Integration
Tab title automatically updates to show your current working directory as you navigate.

### GPU Adapter Selector
Automatically selects the best GPU + Graphics API:
- **Windows:** DirectX 12 > Vulkan > OpenGL
- Uses discrete GPU when available

---

## 📚 References

Original config by: [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config)

- https://wezfurlong.org/wezterm/
- https://starship.rs/
- https://yazi-rs.github.io/
- https://github.com/catppuccin/wezterm

---

## 📝 License

MIT License - See [LICENSE](./LICENSE) file

Original copyright © 2023 Kevin Silvester
