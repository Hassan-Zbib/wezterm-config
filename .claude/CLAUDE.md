# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A modular WezTerm terminal configuration for Windows, themed with Catppuccin Macchiato. The repo lives at `~/Desktop/GitHub/wezterm-config` and is loaded via `~/.wezterm.lua` which adds it to Lua's `package.path`.

## Architecture

### Entry Point & Config Loading

`home/.wezterm.lua` (copied to `~/`) loads everything via a **builder pattern**:

```lua
Config:init()
   :append(require('config.appearance'))
   :append(require('config.bindings'))
   :append(require('config.domains'))
   -- ...
   .options  -- final merged table
```

Each `config/*.lua` module returns a plain options table. `config/init.lua` defines the `Config` builder class that merges them (warns on duplicate keys).

### Event System

Each `events/*.lua` module exports a `setup(opts?)` function called from the entry point:

```lua
require('events.tab-title').setup({ tab_width = 32 })
```

Events use `OptsValidator` for schema validation and register handlers via `wezterm.on('event-name', callback)`.

### Key Utilities

- **`utils/cells.lua`** — Segment-based formatter for `wezterm.format()`. Used by all status bar and tab title events. Create with `Cells:new()`, add segments with `:add_segment(id, text, colors, attrs)`, render with `:render(ids)`.
- **`utils/backdrops.lua`** — Singleton background image manager. **Important:** `:set_images()` must be called in the entry point (uses `wezterm.glob` which requires the main coroutine).
- **`utils/platform.lua`** — Returns `{ is_win, is_linux, is_mac }` for platform branching.
- **`utils/sessions.lua`** — Saves/restores pane layout trees as JSON. Uses `tab:panes_with_info()` positions to build a recursive split tree (direction: `Right` or `Bottom`).
- **`utils/ssh-hosts.lua`** — Parses `~/.ssh/config` at call time. Uses `Cells` for formatted InputSelector labels.

### Platform Modifier Convention

In `config/bindings.lua`, `mod.SUPER` maps to `Alt` on Windows (to avoid conflicts with the Windows key) and `SUPER` on Mac. `mod.SUPER_REV` is `Alt+Ctrl` / `Super+Ctrl`.

## Code Conventions

- **Indentation:** 3 spaces (enforced by `.stylua.toml`)
- **Line endings:** The repo standardizes on LF, but files may have CRLF on Windows. Use binary mode (`'rb'`/`'wb'`) when editing files with Python to preserve existing endings. The Edit tool handles this automatically.
- **starship.toml:** Contains Unicode powerline glyphs (multi-byte). Use Python with raw byte operations to edit the format string — sed and simple string matching will corrupt it.
- **OOP pattern:** Metatable-based classes (`__index = self`), fluent APIs returning `self`.
- **Module exports:** `local M = {} ... return M` for function modules; singleton instances (like `BackDrops:init()`) returned directly.
- **Type annotations:** LuaDoc style (`---@class`, `---@param`, `---@return`).
- **Nerd Font icons:** Referenced via `wezterm.nerdfonts.*` or inline Unicode. JetBrainsMono Nerd Font is required.
- **StyLua ignore:** Use `-- stylua: ignore` above tables that use manual alignment (see bindings.lua key tables).
