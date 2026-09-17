# WezTerm project guidance

This file provides guidance to coding agents working in this repository.

## What This Is

A modular WezTerm terminal configuration for Windows, themed with Catppuccin Macchiato. This repository is loaded via `~/.wezterm.lua` which adds it to Lua's `package.path`.

## Architecture

### Entry Point & Config Loading

`home/.wezterm.lua` (symlinked to `~/` via Dotbot) loads everything via a **builder pattern**:

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

### Cheatsheet

`scripts/cheatsheet.py` is the F1 keyboard shortcut reference displayed in a dedicated tab. It is a standalone Python script (no dependencies beyond stdlib), rendered as an **interactive tabbed pager**: one section per screen, `←/→` or `h`/`l` to cycle, `1`–`9` to jump, `↑/↓` to scroll, `/` to search, `q`/`Esc` to quit. It draws on the alternate screen buffer and reflows when the pane is resized.

Structure:

- **Panels** — `_QUICK_ACTIONS`, `_TABS`, … Each is a list of lines built from `header()`, `row()`, `sub()`, `blank()` and `note()`.
- **`PAGES`** — `(group, tab label, panels)`. Groups (`WEZTERM`, `SHELL`, `CLI`) are only a label on the tab strip; navigation is flat.
- **Cap pages at three panels.** A four-panel page wraps to a second row below 209 columns and forces scrolling. Three keeps every page one screen at both 3 and 4 columns.
- **`INDEX` / `search()`** — panels are pre-coloured strings, so `header()`, `sub()`, `row()` and `note()` record their raw text into `_ROWS`/`_NOTES` as a side effect while the panels are built. `_build_index()` joins those to `PAGES` via the panel title, and **raises if a panel is not placed in `PAGES`** — that assertion is the guard against a panel being defined and forgotten.
- Rows inherit the `sub()` heading above them, so tool names that only ever appear as a heading (`lazygit`, `eza`, `zoxide`) still match. Queries are AND over whitespace-separated tokens, ranked key → description → sub-heading. When nothing matches a row, `search()` falls back to matching whole panels via their `note()` prose and returns entries with `key is None`.

**Keep it in sync:** whenever you add a new keybinding to `config/bindings.lua` or `home/.wezterm.lua`, or add/remove a CLI tool from the setup, update the relevant panel. Use the existing builder calls and don't restructure the layout without good reason.

**Verify after editing** — there is no test runner in this repo, so the script checks itself:

```sh
uv run python scripts/cheatsheet.py --selftest   # layout invariants at 6 terminal sizes
uv run python scripts/cheatsheet.py --all        # non-interactive dump of every page
```

`--selftest` asserts each frame — page view *and* search view — exactly fills the terminal and that no composed line overruns the width (the columns are laid out with absolute-column `CSI G` escapes, so an over-long `row()` description silently wraps and corrupts the grid). Piping stdout also triggers the `--all` dump, since the pager needs a tty.

### Platform Modifier Convention

In `config/bindings.lua`, `mod.SUPER` maps to `Alt` on Windows (to avoid conflicts with the Windows key) and `SUPER` on Mac. `mod.SUPER_REV` is `Alt+Ctrl` / `Super+Ctrl`.

## Code Conventions

- **Indentation:** 3 spaces (enforced by `.stylua.toml`)
- **Line endings:** The repo standardizes on LF, but files may have CRLF on Windows. Use binary mode (`'rb'`/`'wb'`) when editing files with Python to preserve existing endings. The Edit tool handles this automatically.
- **starship.toml:** Lives at `home/.config/starship.toml`. Contains Unicode powerline glyphs (multi-byte). Use Python with raw byte operations to edit the format string — sed and simple string matching will corrupt it.
- **Dotfiles:** All files under `home/` are symlinked to `~` via Dotbot (`./install`). The `home/` directory mirrors `~` structure.
- **OOP pattern:** Metatable-based classes (`__index = self`), fluent APIs returning `self`.
- **Module exports:** `local M = {} ... return M` for function modules; singleton instances (like `BackDrops:init()`) returned directly.
- **Type annotations:** LuaDoc style (`---@class`, `---@param`, `---@return`).
- **Nerd Font icons:** Referenced via `wezterm.nerdfonts.*` or inline Unicode. JetBrainsMono Nerd Font is required.
- **StyLua ignore:** Use `-- stylua: ignore` above tables that use manual alignment (see bindings.lua key tables).
