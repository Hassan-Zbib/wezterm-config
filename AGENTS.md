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

`scripts/cheatsheet.py` is the F1 keyboard shortcut reference displayed in a dedicated tab. It is a standalone Python script (no dependencies beyond stdlib), rendered as an **interactive tabbed pager**: one section per screen, `←/→` or `h`/`l` to cycle, `1`–`9` to jump, `↑/↓` to scroll, `/` to search, `q`/`Esc` to quit. It draws on the alternate screen buffer and reflows when the pane is resized. It opens on the home page, which reports whether the running WezTerm nightly is current.

Jumping reads a single keypress, so pages past 9 are reachable only with `←`/`→`.

Structure:

- **Panels** — `_QUICK_ACTIONS`, `_TABS`, … Each is a list of lines built from `header()`, `row()`, `sub()`, `blank()` and `note()`.
- **`PAGES`** — `(group, tab label, panels)`. Groups (`WEZTERM`, `SHELL`, `CLI`) are only a label on the tab strip; navigation is flat.
- **Cap pages at three panels.** A four-panel page wraps to a second row below 209 columns and forces scrolling. Three keeps every page one screen at both 3 and 4 columns.
- **Panel lines must fit 48 columns (`COL_W` + indent) — except on single-panel pages.** `compose_cols()` only emits `CSI G` column jumps when there is a next column, so a lone panel has nothing to overwrite and is bounded only by the terminal. `header(title, width)` exists for exactly that case: the home page draws its rule at `_HOME_W` to match the full compare URL it prints. `--selftest` skips the column check for single-panel pages and relies on the frame check instead.
- **`INDEX` / `search()`** — panels are pre-coloured strings, so `header()`, `sub()`, `row()` and `note()` record their raw text into `_ROWS`/`_NOTES` as a side effect while the panels are built. `_build_index()` joins those to `PAGES` via the panel title, and **raises if a panel is not placed in `PAGES`** — that assertion is the guard against a panel being defined and forgotten.
- Rows inherit the `sub()` heading above them, so tool names that only ever appear as a heading (`lazygit`, `eza`, `zoxide`) still match. Queries are AND over whitespace-separated tokens, ranked key → description → sub-heading. When nothing matches a row, `search()` falls back to matching whole panels via their `note()` prose and returns entries with `key is None`.
- A panel contributing no `row()` is absent from `PANEL_TEXT` too, so **its `note()` prose is unsearchable** — keep at least one static row in any panel worth finding.

#### The home page (nightly version check)

Page 1 is the only page rebuilt after import. It reports the installed build, the published nightly, how many commits separate them, and a compare URL for reading them.

- **Where the numbers come from** — `wezterm --version` prints `<build stamp>-<commit>`; that commit drives `compare/<commit>...main`. The rolling `nightly` release tag is useless for versioning (`published_at` is frozen in 2019, no asset name carries a version), so the installer asset's mtime stands in for "when the nightly was last built", and commits newer than it are dropped. Without that filter the page overstates the gap by however many commits landed since the last build.
- **Ask `wezterm.exe`, not `$WEZTERM_EXECUTABLE`.** That variable points at whichever binary owns the pane, and in a normal window that is `wezterm-gui.exe` — which answers `--version` with `wezterm-gui someone forgot to call assign_version_info` and no version at all. Only under the mux server does it happen to answer for itself. `_version_candidates()` uses its *directory* to find the sibling `wezterm.exe` and falls back to `PATH`.
- **It links to the changelog rather than reproducing it.** A count plus a compare URL replaced two panels of commit subjects, so the page is a single panel and can never disagree with what GitHub actually shows. **Keep the URL whole, scheme included** (`_COMPARE`): the bare-URL rule in `config/general.lua` needs `\w+://` to fire, so a prettified or wrapped URL would stop being Ctrl+clickable and become plain text. That is also why the panel is allowed past `COL_W`.
- **Best-effort, never blocking** — the check runs on a daemon thread, results cache to `nightly.json` under `LOCALAPPDATA`/`XDG_CACHE_HOME` for 6h, and every failure degrades to the cached answer or a one-line reason. `_publish()` swaps the panels, drops their `_BODY_CACHE` entries, *then* bumps `_GEN`; `run()` watches `_GEN` to redraw. Keep that order.
- **`_HOME_H` is load-bearing.** `_masthead()` sizes the banner off the tallest page, so a home page that grew when the check landed would pop the banner in and out. The home panel is pinned to `_HOME_H` lines, chosen to stay *under* the tallest static page at 1, 2, 3 and 4 columns. `--selftest` asserts both.
- **The panel title must be identical in every state**, because `INDEX` joins rows to pages by title. Dynamic values (version stamps) deliberately bypass `row()` via `_ver_row()` so whatever the check returned at import does not end up in the search index.
- `_RECORD` is switched off once `INDEX` is built, so runtime rebuilds do not append duplicates to `_ROWS`/`_NOTES`.

**Keep it in sync:** whenever you add a new keybinding to `config/bindings.lua` or `home/.wezterm.lua`, or add/remove a CLI tool from the setup, update the relevant panel. Use the existing builder calls and don't restructure the layout without good reason.

**Verify after editing** — there is no test runner in this repo, so the script checks itself:

```sh
uv run python scripts/cheatsheet.py --selftest   # layout invariants at 6 terminal sizes
uv run python scripts/cheatsheet.py --all        # non-interactive dump of every page
```

`--selftest` asserts each frame — page view *and* search view — exactly fills the terminal and that no composed line overruns the width. It also measures every panel *before* composition against its own 48 columns: because the columns are laid out with absolute-column `CSI G` escapes, an over-long `row()` description does not make the line longer, it silently overwrites the next separator and corrupts the grid. The home page is driven through every state it can reach (`_DEMO`) so none of that depends on the network. Piping stdout also triggers the `--all` dump, since the pager needs a tty; the dump reads the version cache but never hits the network.

### Upgrading WezTerm

`scripts/wezterm-upgrade.sh` downloads the nightly installer, verifies it against the `.sha256` CI publishes beside it, and refuses to keep a file that does not match. `--install` launches it; `--force` re-downloads; `--dir` overrides `~/Downloads`.

**Do not route nightly upgrades through winget.** `wez.wezterm.nightly` points at the rolling `nightly` release tag, so the hash recorded in the manifest goes stale the moment CI rebuilds and every `winget upgrade` fails with `Installer hash does not match`. The only way past it is `--ignore-security-hash`, which does not weaken a check — it removes the only one there is. The manifest's *version* is equally stale, so even when forced it can install a build days older than what is published. `dotbot-winget` is unaffected: it passes `--no-upgrade` and skips anything already installed, so `./install` provisions WezTerm but never updates it.

The script's hash comes from the same host as the installer, so it cannot prove the release itself is honest — TLS to github.com is the trust anchor, exactly as for winget on a fresh install. What it does catch is a truncated or corrupted 45MB download, which is the failure that actually happens. Contrast `scripts/install-zsh.sh`, where the hash is a pinned constant because the MSYS2 mirror is untrusted and unsigned; pinning is impossible for a nightly whose asset legitimately changes daily.

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
