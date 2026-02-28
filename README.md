<h2 align="center">My WezTerm Config</h2>

<p align="center">
  <a href="https://github.com/Hassan-Zbib/wezterm-config">
    <img alt="Private Repo" src="https://img.shields.io/badge/repo-private-red?style=for-the-badge&logo=github&labelColor=302D41">
  </a>
</p>

![screenshot](./.github/screenshots/wezterm.gif)

> **Note:** This is a customized fork of [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config)

---

## 🪟 Windows Setup

### Requirements

- **WezTerm** (Minimum: `20240127-113634-bbcac864`, Recommended: [Nightly](https://github.com/wez/wezterm/releases/nightly))
- **PowerShell 7** ([Download](https://github.com/PowerShell/PowerShell/releases/latest))
- **JetBrainsMono Nerd Font**

### Install WezTerm on Windows

**Using winget:**
```sh
winget install wez.wezterm
```

**Using Scoop:**
```sh
scoop bucket add extras
scoop install wezterm
```

**Using Chocolatey:**
```sh
choco install wezterm -y
```

### Install JetBrainsMono Nerd Font

**Using Scoop:**
```sh
scoop bucket add nerd-fonts
scoop install JetBrainsMono-NF
```

Or download from: https://www.nerdfonts.com/

### Installation

```sh
# Clone to your preferred location
git clone https://github.com/Hassan-Zbib/wezterm-config.git C:\Users\YOUR-USERNAME\Desktop\GitHub\wezterm-config

# The .wezterm.lua file in your home directory references this repo
```

### Configuration Files

- `config/appearance.lua` - Colors, opacity, cursor, backgrounds
- `config/fonts.lua` - Font settings
- `config/bindings.lua` - All keyboard shortcuts
- `config/launch.lua` - Default shell and launch menu (PowerShell 7, Git Bash, WSL, CMD)
- `config/domains.lua` - WSL and SSH connection settings
- `backdrops/` - Background wallpaper images

---

## ⌨️ Keyboard Shortcuts Cheat Sheet

### 🎯 Quick Actions
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>F1</kbd> | Copy Mode | <kbd>F11</kbd> | Fullscreen |
| <kbd>F2</kbd> | Command Palette | <kbd>F12</kbd> | Debug Overlay |
| <kbd>F3</kbd> | Launcher Menu | <kbd>Alt</kbd>+<kbd>f</kbd> | Search |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd> | Copy | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>u</kbd> | Open URL |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd> | Paste | | |

### ✏️ Cursor Movement
| Keys | Action |
| ---- | ------ |
| <kbd>Alt</kbd>+<kbd>←</kbd> | Jump to Line Start |
| <kbd>Alt</kbd>+<kbd>→</kbd> | Jump to Line End |
| <kbd>Alt</kbd>+<kbd>Backspace</kbd> | Clear Line *(doesn't work in PowerShell/CMD)* |

### 📑 Tabs
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>Alt</kbd>+<kbd>t</kbd> | New Tab | <kbd>Alt</kbd>+<kbd>[</kbd> | Next Tab |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>t</kbd> | New Tab (WSL) | <kbd>Alt</kbd>+<kbd>]</kbd> | Previous Tab |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>w</kbd> | Close Tab | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>[</kbd> | Move Tab Left |
| <kbd>Alt</kbd>+<kbd>0</kbd> | Rename Tab | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>]</kbd> | Move Tab Right |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>0</kbd> | Undo Rename | <kbd>Alt</kbd>+<kbd>9</kbd> | Toggle Tab Bar |

### 🪟 Panes (Split Screen)
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>Alt</kbd>+<kbd>\\</kbd> | Split Vertical | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>k</kbd> | Move Up |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>\\</kbd> | Split Horizontal | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>j</kbd> | Move Down |
| <kbd>Alt</kbd>+<kbd>w</kbd> | Close Pane | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>h</kbd> | Move Left |
| <kbd>Alt</kbd>+<kbd>Enter</kbd> | Zoom Pane | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>l</kbd> | Move Right |
| | | <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>p</kbd> | Swap Panes |

### 🖼️ Background Images
| Keys | Action | Keys | Action |
| ---- | ------ | ---- | ------ |
| <kbd>Alt</kbd>+<kbd>/</kbd> | Random Image | <kbd>Alt</kbd>+<kbd>,</kbd> | Next Image |
| <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>/</kbd> | Search Images | <kbd>Alt</kbd>+<kbd>.</kbd> | Previous Image |
| <kbd>Alt</kbd>+<kbd>b</kbd> | Toggle Background | | |

### 🔤 Font & Window
| Keys | Action |
| ---- | ------ |
| <kbd>Alt</kbd>+<kbd>=</kbd> | Increase Font |
| <kbd>Alt</kbd>+<kbd>-</kbd> | Decrease Font |
| <kbd>Alt</kbd>+<kbd>n</kbd> | New Window |

### 📜 Scrolling
| Keys | Action |
| ---- | ------ |
| <kbd>Alt</kbd>+<kbd>u</kbd> | Scroll Up (5 lines) |
| <kbd>Alt</kbd>+<kbd>d</kbd> | Scroll Down (5 lines) |
| <kbd>Page Up</kbd> / <kbd>Page Down</kbd> | Scroll Page |

### ⚙️ Advanced Modes
**Leader Key:** <kbd>Alt</kbd>+<kbd>Ctrl</kbd>+<kbd>Space</kbd>, then:
- <kbd>f</kbd> → Font Resize Mode (<kbd>k</kbd>/<kbd>j</kbd> to resize, <kbd>r</kbd> to reset, <kbd>Esc</kbd> to exit)
- <kbd>p</kbd> → Pane Resize Mode (<kbd>h</kbd>/<kbd>j</kbd>/<kbd>k</kbd>/<kbd>l</kbd> to resize, <kbd>Esc</kbd> to exit)

---

## 🎨 Customization

### Change Background Opacity
Edit `config/appearance.lua`:
```lua
window_background_opacity = 0.85  -- 15% transparent (current setting)
```

### Add Background Images
Add your wallpapers to the `backdrops/` folder (supports jpg, png, gif, etc.)

### Change Default Shell
Edit `config/launch.lua`:
```lua
options.default_prog = { 'wsl.exe', '-d', 'Ubuntu' }  -- Switch to WSL
```

### Modify Colors
Edit `colors/custom.lua` to change the color scheme

---

## 🔧 Features

### Background Image Selector
- Cycle through wallpapers
- Fuzzy search for specific image
- Toggle background on/off (focus mode)

### GPU Adapter Selector
Automatically selects the best GPU + Graphics API combo:
- **Windows:** DirectX 12 > Vulkan > OpenGL
- Uses discrete GPU when available
- Only works with `front_end = 'WebGpu'`

### WSL Integration
- Direct WSL Ubuntu access
- Configured domains in `config/domains.lua`

---

## 📚 References

Original config by: [KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config)

Additional inspirations:
- https://github.com/catppuccin/wezterm
- https://wezfurlong.org/wezterm/

---

## 📝 License

MIT License - See [LICENSE](./LICENSE) file

Original copyright © 2023 Kevin Silvester
