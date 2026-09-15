local wezterm = require('wezterm')
local platform = require('utils.platform')
local backdrops = require('utils.backdrops')
local ssh_hosts = require('utils.ssh-hosts')
local domain_manager = require('utils.domains')
local sessions = require('utils.sessions')
local workspaces = require('utils.workspaces')
local act = wezterm.action

local mod = {}
local is_maximized = false

if platform.is_mac then
   mod.SUPER = 'SUPER'
   mod.SUPER_REV = 'SUPER|CTRL'
elseif platform.is_win or platform.is_linux then
   mod.SUPER = 'ALT' -- to not conflict with Windows key shortcuts
   mod.SUPER_REV = 'ALT|CTRL'
end

-- stylua: ignore
local keys = {
   -- misc/useful --
   {
      key = 'F1',
      mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
         local home = wezterm.home_dir:gsub('\\', '/')
         local drive = home:sub(1, 1):lower()
         local unix_home = '/' .. drive .. home:sub(3)
         local script = unix_home .. '/Desktop/GitHub/Hassan-Zbib/wezterm-config/scripts/cheatsheet.py'
         window:perform_action(act.SpawnCommandInNewTab({
            args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '--login', '-c', 'uv run python "' .. script .. '"' },
         }), pane)
      end),
   },
   { key = 'F2', mods = 'NONE', action = 'ActivateCopyMode' },
   { key = 'F3', mods = 'NONE', action = act.ShowLauncher },
   { key = 'F4', mods = 'NONE', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },
   -- F5 opens the Workspaces & Sessions hub: switch/new/rename a workspace and
   -- every session action, in one menu. A workspace is live state and a session
   -- is a saved snapshot of one, so they belong together -- this replaces what
   -- used to be F5 / Shift+F5 / Ctrl+F5 / F10 across two separate menus.
   {
      key = 'F5',
      mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
         workspaces.hub(window, pane)
      end),
   },
   -- F6 quick-saves the current workspace over the session it is attached to,
   -- prompting for a name only the first time. Everything else is behind F5,
   -- so the two session keys sit next to each other.
   {
      key = 'F6',
      mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
         sessions.save(window, pane)
      end),
   },
   {
      key = 'F7',
      mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
         window:perform_action(act.InputSelector({
            title = 'SSH Hosts',
            choices = ssh_hosts.choices(),
            fuzzy = true,
            fuzzy_description = 'Connect to SSH Host: ',
            action = wezterm.action_callback(function(inner_window, inner_pane, id)
               if id then
                  ssh_hosts.connect(inner_pane, id)
               end
            end),
         }), pane)
      end),
   },
   { key = 'F8', mods = 'NONE', action = act.ActivateCommandPalette },
   -- F9 and F10 are unbound. F9 was the session quick-save (now F6, next to the
   -- F5 hub); F10 was the session manager, now folded into that hub.
   { key = 'F11', mods = 'NONE',    action = act.ToggleFullScreen },
   { key = 'F12', mods = 'NONE',    action = act.ShowDebugOverlay },
   { key = 'f',   mods = mod.SUPER, action = act.Search({ CaseInSensitiveString = '' }) },
   {
      key = 'u',
      mods = mod.SUPER_REV,
      action = wezterm.action.QuickSelectArgs({
         label = 'open url',
         patterns = {
            '\\((https?://\\S+)\\)',
            '\\[(https?://\\S+)\\]',
            '\\{(https?://\\S+)\\}',
            '<(https?://\\S+)>',
            '\\bhttps?://\\S+[)/a-zA-Z0-9-]+'
         },
         action = wezterm.action_callback(function(window, pane)
            local url = window:get_selection_text_for_pane(pane)
            wezterm.log_info('opening: ' .. url)
            wezterm.open_with(url)
         end),
      }),
   },

   -- cursor movement --
   -- Alt+Left/Right send SS3 Home/End; readline maps \eOH/\eOF to
   -- beginning-of-line / end-of-line.
   { key = 'LeftArrow',  mods = mod.SUPER,     action = act.SendString '\u{1b}OH' },
   { key = 'RightArrow', mods = mod.SUPER,     action = act.SendString '\u{1b}OF' },
   -- Alt+Backspace sends Meta-DEL (\e\x7f) = backward-kill-word, matching bash,
   -- Claude Code and Warp's editor:delete_word_left. It previously sent \x15
   -- (C-u), which wiped the whole line -- unrecoverable in Claude Code, which
   -- has no kill ring. Ctrl+U still does the line-wide kill.
   { key = 'Backspace',  mods = mod.SUPER,     action = act.SendString '\u{1b}\u{7f}' },
   -- Ctrl+Shift+Backspace clears the whole line, matching Warp's
   -- editor_view:clear_buffer. Sends C-e then C-u (end-of-line, then kill to
   -- line start) so it wipes the line regardless of cursor position -- C-u
   -- alone would only kill backwards from the cursor.
   { key = 'Backspace',  mods = 'CTRL|SHIFT',  action = act.SendString '\u{5}\u{15}' },

   -- copy/paste --
   { key = 'c',          mods = 'CTRL|SHIFT',  action = act.CopyTo('Clipboard') },
   { key = 'v',          mods = 'CTRL|SHIFT',  action = act.PasteFrom('Clipboard') },

   -- reload config --
   { key = 'r',          mods = 'CTRL|SHIFT',  action = act.ReloadConfiguration },

   -- tabs --
   -- tabs: spawn+close
   { key = 't',          mods = mod.SUPER,     action = act.SpawnTab('DefaultDomain') },
   -- Alt+Ctrl+Shift+t spawns into WSL. WezTerm reports this as `ALT|CTRL T` --
   -- an uppercase key name means the shifted form -- so it is a distinct binding
   -- from the lowercase `ALT|CTRL t` further down, and the two do not collide.
   -- Previously pointed at a domain named 'wsl:ubuntu-fish' that was never
   -- declared in config/domains.lua, so pressing it did nothing.
   { key = 't',          mods = mod.SUPER_REV .. '|SHIFT', action = act.SpawnTab({ DomainName = 'WSL:Ubuntu' }) },
   { key = 'w',          mods = mod.SUPER_REV, action = act.CloseCurrentTab({ confirm = false }) },

   -- domains / mux --
   -- Alt+Ctrl+m opens the manager (spawn into a domain, detach, restart the mux
   -- server). Restart is destructive, so it sits behind a second confirmation
   -- inside the menu rather than on a bare keystroke.
   {
      key = 'm',
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, pane)
         domain_manager.manager(window, pane)
      end),
   },
   -- Escape hatch: a throwaway tab owned by the GUI, not the mux server. Dies
   -- with the window, which is what you want for a quick one-off shell.
   -- Sits next to Alt+t (new tab) deliberately: same gesture, disposable domain.
   -- This claims the Alt+Ctrl+t slot that was previously held open to mirror
   -- Warp's "reopen closed session" -- that Warp parity is now gone.
   { key = 't',          mods = mod.SUPER_REV, action = act.SpawnCommandInNewTab({ domain = { DomainName = 'local' } }) },

   -- tabs: navigation
   { key = '[',          mods = mod.SUPER,     action = act.ActivateTabRelative(-1) },
   { key = ']',          mods = mod.SUPER,     action = act.ActivateTabRelative(1) },

   -- tabs: reorder (matches Warp's workspace:move_tab_left/right)
   { key = 'LeftArrow',  mods = 'CTRL|SHIFT',  action = act.MoveTabRelative(-1) },
   { key = 'RightArrow', mods = 'CTRL|SHIFT',  action = act.MoveTabRelative(1) },

   -- workspaces: cycle
   { key = '[',          mods = mod.SUPER_REV, action = act.SwitchWorkspaceRelative(-1) },
   { key = ']',          mods = mod.SUPER_REV, action = act.SwitchWorkspaceRelative(1) },

   -- tab: title
   { key = '0',          mods = mod.SUPER,     action = act.EmitEvent('tabs.manual-update-tab-title') },
   { key = '0',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.reset-tab-title') },

   -- tab: hide tab-bar
   -- Moved off Alt+9 (and Alt+8 below) to free the whole Alt+1..9 range for the
   -- tab-index jumps appended after this table. Both are rare view toggles, so
   -- they lose nothing by sitting one tier up, and Alt+Ctrl is where this config
   -- already puts the larger-scope variant of an Alt binding.
   { key = '9',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.toggle-tab-bar'), },

   -- tab: flip top <-> bottom
   { key = '8',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.toggle-tab-bar-position'), },

   -- window --
   -- window: spawn windows
   -- Spawns a plain window. It used to also type the `ff` shell alias, which
   -- made the binding depend on a shell definition that nothing here declares:
   -- if the alias were missing or renamed you got a stray command instead of a
   -- clean prompt, and the cheatsheet said only "New window".
   {
      key = 'n', mods = mod.SUPER,
      action = wezterm.action_callback(function(_window, _pane)
         wezterm.mux.spawn_window({})
      end),
   },

   -- window: zoom window
   {
      key = '-',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local dimensions = window:get_dimensions()
         if dimensions.is_full_screen or is_maximized then
            return
         end
         local new_width = dimensions.pixel_width - 50
         local new_height = dimensions.pixel_height - 50
         window:set_inner_size(new_width, new_height)
      end)
   },
   {
      key = '=',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local dimensions = window:get_dimensions()
         if dimensions.is_full_screen or is_maximized then
            return
         end
         local new_width = dimensions.pixel_width + 50
         local new_height = dimensions.pixel_height + 50
         window:set_inner_size(new_width, new_height)
      end)
   },
   {
      key = 'Enter',
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, _pane)
         if is_maximized then
            window:restore()
            is_maximized = false
         else
            window:maximize()
            is_maximized = true
         end
      end)
   },

   -- paste image from clipboard as file path (for Claude Code) --
   {
      key = 'v',
      mods = 'ALT|SHIFT',
      action = wezterm.action_callback(function(window, pane)
         local success, stdout, _ = wezterm.run_child_process({
            'powershell.exe', '-NoProfile', '-Command',
            [[
               Add-Type -AssemblyName System.Windows.Forms
               Add-Type -AssemblyName System.Drawing
               $img = [System.Windows.Forms.Clipboard]::GetImage()
               if ($img) {
                  $path = $env:TEMP + "\claude-paste-" + (Get-Date -Format "yyyyMMddHHmmss") + ".png"
                  $img.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
                  Write-Output $path
               }
            ]]
         })
         if success and stdout and #stdout > 0 then
            local path = stdout:gsub('[\r\n]+$', '')
            pane:send_text(path)
         end
      end),
   },

   -- background controls --
   {
      key = [[/]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:random(window)
      end),
   },
   {
      key = [[,]],
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:prev_category(window)
      end),
   },
   {
      key = [[.]],
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:next_category(window)
      end),
   },
   {
      key = [[/]],
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, pane)
         if backdrops.focus_on then return end
         if window:active_key_table() == 'browse_backdrop' then return end
         backdrops:enter_browse_mode(window)
         window:perform_action(act.ActivateKeyTable({
            name = 'browse_backdrop',
            one_shot = false,
            timeout_milliseconds = 30000,
         }), pane)
      end),
   },
   {
      key = 'b',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:toggle_focus(window)
      end)
   },
   {
      key = 'r',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(_window, _pane)
         backdrops:toggle_auto_rotate()
      end),
   },
   {
      key = ',',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:adjust_overlay_opacity(window, -0.05)
      end),
   },
   {
      key = '.',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:adjust_overlay_opacity(window, 0.05)
      end),
   },

   -- panes --
   -- panes: split panes
   {
      key = [[\]],
      mods = mod.SUPER,
      action = act.SplitPane({ direction = 'Down', size = { Percent = 40 } }),
   },
   {
      key = [[\]],
      mods = mod.SUPER_REV,
      action = act.SplitPane({ direction = 'Right', size = { Percent = 40 } }),
   },

   -- Shift+Enter inserts a newline in readline/bash via bracketed paste
   { key = 'Enter', mods = 'SHIFT', action = act.SendString('\x1b[200~\n\x1b[201~') },

   -- panes: zoom+close pane
   { key = 'Enter', mods = mod.SUPER,     action = act.TogglePaneZoomState },
   { key = 'w',     mods = mod.SUPER,     action = act.CloseCurrentPane({ confirm = false }) },

   -- panes: navigation
   { key = 'UpArrow',    mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Up') },
   { key = 'DownArrow',  mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Down') },
   { key = 'LeftArrow',  mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Left') },
   { key = 'RightArrow', mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Right') },
   {
      key = 'p',
      mods = mod.SUPER_REV,
      action = act.PaneSelect({ alphabet = '1234567890', mode = 'SwapWithActiveKeepFocus' }),
   },

   -- panes: resize (flat bindings)
   { key = 'UpArrow',    mods = 'ALT|SHIFT', action = act.AdjustPaneSize({ 'Up', 2 }) },
   { key = 'DownArrow',  mods = 'ALT|SHIFT', action = act.AdjustPaneSize({ 'Down', 2 }) },
   { key = 'LeftArrow',  mods = 'ALT|SHIFT', action = act.AdjustPaneSize({ 'Left', 2 }) },
   { key = 'RightArrow', mods = 'ALT|SHIFT', action = act.AdjustPaneSize({ 'Right', 2 }) },

   -- panes: scroll pane
   --
   -- Scrolling lives on a modifier, and the BARE keys are deliberately left
   -- UNBOUND so they reach the application. `disable_default_key_bindings` is
   -- on, so unbound really means unbound.
   --
   -- They used to be bound to a `scroll_or_send` callback that scrolled when
   -- `scrollback_rows > viewport_rows` and forwarded the key otherwise, using
   -- "no scrollback" as a stand-in for "a full-screen app is running". That
   -- holds for alternate-screen TUIs (yazi, vim, less) but NOT for Claude
   -- Code, which renders inline on the primary screen -- that is why its
   -- transcript survives in the scrollback after you quit. So the pane always
   -- had scrollback, the predicate always said "scroll", and PageUp dragged
   -- WezTerm's scrollbar instead of scrolling Claude Code's transcript. It
   -- only ever appeared to work in a freshly spawned pane, before ~10 lines
   -- had scrolled off the top.
   --
   -- The predicate cannot be repaired from the GUI side either. Every pane
   -- here is a `ClientPane` -- the GUI is a mux client -- and `ClientPane`
   -- hardcodes `is_alt_screen_active()` to `false` (the mux protocol carries
   -- no alt-screen field) and reports no process info. So nothing tells "zsh
   -- with history" apart from "Claude Code with history" without a shell-side
   -- OSC 1337 user var. A modifier is deterministic, costs nothing, and
   -- matches the xterm convention where Shift+PgUp is the terminal's own
   -- scroll.
   --
   -- Bare Home/End are freed for the same reason, which also hands them back
   -- to zle/readline for line-start and line-end.
   { key = 'PageUp',   mods = 'SHIFT',   action = act.ScrollByPage(-0.75) },
   { key = 'PageDown', mods = 'SHIFT',   action = act.ScrollByPage(0.75) },
   { key = 'Home',     mods = 'SHIFT',   action = act.ScrollToTop },
   { key = 'End',      mods = 'SHIFT',   action = act.ScrollToBottom },
   { key = 'PageUp',   mods = 'ALT',     action = act.ScrollByLine(-5) },
   { key = 'PageDown', mods = 'ALT',     action = act.ScrollByLine(5) },

   -- Shift+Up / Shift+Down are deliberately UNBOUND.
   --
   -- They used to be ScrollToPrompt(-1/+1) -- jump to the previous/next shell
   -- prompt -- which cannot work here. ScrollToPrompt walks OSC 133 semantic
   -- zones, and `ClientPane` does not implement `get_semantic_zones` at all: it
   -- falls through to the trait default, which is empty. Every pane in this
   -- config is a ClientPane because the GUI is a mux client, so the action had
   -- nothing to jump between and the keys silently did nothing.
   --
   -- The shells are not at fault. zsh and bash both emit the marks correctly --
   -- verified by reading 3 Prompt + 3 Output zones back from a live pane of
   -- each. It is wezterm#2880, open since Dec 2022; PR #8078 would carry
   -- semantic zones over the mux protocol but is still unreviewed. A Lua
   -- reimplementation is equally impossible, because `pane:get_semantic_zones()`
   -- is empty client-side for exactly the same reason.
   --
   -- They are left unbound rather than repointed at a scroll action: the two
   -- tiers below (¾ page on the bare keys, 5 lines on Alt) already cover
   -- scrolling, and a third tier would just be Alt+PgUp with a different
   -- number. Leaving them free also hands the keys to zsh, which is where
   -- zsh-history-substring-search expects them if that ever gets installed.

   -- key-tables --
   -- resizes fonts
   {
      key = 'f',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_font',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
   -- There is no `LEADER p` pane-resize mode: the flat Alt+Shift+arrows above
   -- already resize panes, and two gestures for one job is how you end up
   -- remembering neither.
}

-- tabs: jump to index
--
-- Mirrors herdr's stock `prefix+1..9`, so tab indexing is the same gesture at
-- both layers -- swap Alt for the herdr prefix and the digit is unchanged.
-- Nothing occupied Alt+1..7 before this; Alt+8 and Alt+9 were the two tab-bar
-- toggles and were moved up to Alt+Ctrl in the table above to make room.
--
-- Appended in a loop rather than written as nine literal rows: the table above
-- is `-- stylua: ignore`d because its columns are hand-aligned, and nine
-- near-identical entries gain nothing from that.
for i = 1, 9 do
   table.insert(keys, { key = tostring(i), mods = mod.SUPER, action = act.ActivateTab(i - 1) })
end

-- stylua: ignore
local key_tables = {
   resize_font = {
      { key = 'UpArrow',   action = act.IncreaseFontSize },
      { key = 'DownArrow', action = act.DecreaseFontSize },
      { key = 'r',         action = act.ResetFontSize },
      { key = 'Escape',    action = 'PopKeyTable' },
      { key = 'q',         action = 'PopKeyTable' },
   },
   copy_mode = {
      -- movement: arrow keys
      { key = 'LeftArrow',  mods = 'NONE', action = act.CopyMode('MoveLeft') },
      { key = 'DownArrow',  mods = 'NONE', action = act.CopyMode('MoveDown') },
      { key = 'UpArrow',    mods = 'NONE', action = act.CopyMode('MoveUp') },
      { key = 'RightArrow', mods = 'NONE', action = act.CopyMode('MoveRight') },
      -- movement: word
      { key = 'w',          mods = 'NONE', action = act.CopyMode('MoveForwardWord') },
      { key = 'b',          mods = 'NONE', action = act.CopyMode('MoveBackwardWord') },
      { key = 'e',          mods = 'NONE', action = act.CopyMode('MoveForwardWordEnd') },
      { key = 'RightArrow', mods = 'CTRL', action = act.CopyMode('MoveForwardWord') },
      { key = 'LeftArrow',  mods = 'CTRL', action = act.CopyMode('MoveBackwardWord') },
      -- movement: line
      { key = '0',          mods = 'NONE', action = act.CopyMode('MoveToStartOfLine') },
      { key = '$',          mods = 'NONE', action = act.CopyMode('MoveToEndOfLineContent') },
      { key = '^',          mods = 'NONE', action = act.CopyMode('MoveToStartOfLineContent') },
      { key = 'Home',       mods = 'NONE', action = act.CopyMode('MoveToStartOfLine') },
      { key = 'End',        mods = 'NONE', action = act.CopyMode('MoveToEndOfLineContent') },
      -- movement: viewport/scrollback
      { key = 'g',          mods = 'NONE', action = act.CopyMode('MoveToScrollbackTop') },
      { key = 'G',          mods = 'NONE', action = act.CopyMode('MoveToScrollbackBottom') },
      { key = 'H',          mods = 'NONE', action = act.CopyMode('MoveToViewportTop') },
      { key = 'M',          mods = 'NONE', action = act.CopyMode('MoveToViewportMiddle') },
      { key = 'L',          mods = 'NONE', action = act.CopyMode('MoveToViewportBottom') },
      { key = 'Home',       mods = 'CTRL', action = act.CopyMode('MoveToScrollbackTop') },
      { key = 'End',        mods = 'CTRL', action = act.CopyMode('MoveToScrollbackBottom') },
      -- movement: paging
      { key = 'PageUp',     mods = 'NONE', action = act.CopyMode({ MoveByPage = -1 }) },
      { key = 'PageDown',   mods = 'NONE', action = act.CopyMode({ MoveByPage = 1 }) },
      { key = 'u',          mods = 'CTRL', action = act.CopyMode({ MoveByPage = -0.5 }) },
      { key = 'd',          mods = 'CTRL', action = act.CopyMode({ MoveByPage = 0.5 }) },
      -- selection
      { key = 'v',          mods = 'NONE', action = act.CopyMode({ SetSelectionMode = 'Cell' }) },
      { key = 'V',          mods = 'NONE', action = act.CopyMode({ SetSelectionMode = 'Line' }) },
      { key = 'v',          mods = 'CTRL', action = act.CopyMode({ SetSelectionMode = 'Block' }) },
      -- copy + exit
      { key = 'y',          mods = 'NONE', action = act.Multiple({ act.CopyTo('ClipboardAndPrimarySelection'), act.CopyMode('Close') }) },
      { key = 'Return',     mods = 'NONE', action = act.Multiple({ act.CopyTo('ClipboardAndPrimarySelection'), act.CopyMode('Close') }) },
      -- search
      { key = '/',          mods = 'NONE', action = act.Search('CurrentSelectionOrEmptyString') },
      { key = 'n',          mods = 'NONE', action = act.CopyMode('NextMatch') },
      { key = 'N',          mods = 'NONE', action = act.CopyMode('PriorMatch') },
      { key = 'g',          mods = 'CTRL', action = act.CopyMode('ClearPattern') },
      -- exit
      { key = 'q',          mods = 'NONE', action = act.CopyMode('Close') },
      { key = 'Escape',     mods = 'NONE', action = act.CopyMode('Close') },
   },
   browse_backdrop = {
      -- stylua: ignore
      { key = 'RightArrow', mods = 'NONE', action = wezterm.action_callback(function(win, pane) backdrops:browse_next(win, pane) end) },
      { key = 'LeftArrow',  mods = 'NONE', action = wezterm.action_callback(function(win, pane) backdrops:browse_prev(win, pane) end) },
      { key = '.',          mods = 'NONE', action = wezterm.action_callback(function(win, pane) backdrops:browse_next(win, pane) end) },
      { key = ',',          mods = 'NONE', action = wezterm.action_callback(function(win, pane) backdrops:browse_prev(win, pane) end) },
      { key = 'Return',     mods = 'NONE', action = wezterm.action_callback(function(win, pane) backdrops:browse_confirm(win, pane) end) },
      { key = 'Escape',     mods = 'NONE', action = wezterm.action_callback(function(win, pane) backdrops:browse_cancel(win, pane) end) },
      { key = 'q',          mods = 'NONE', action = wezterm.action_callback(function(win, pane) backdrops:browse_cancel(win, pane) end) },
   },
}

local mouse_bindings = {
   -- Ctrl-click will open the link under the mouse cursor
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
   },
   -- Middle-click: copy selection
   {
      event = { Down = { streak = 1, button = 'Middle' } },
      mods = 'NONE',
      action = act.CopyTo('ClipboardAndPrimarySelection'),
   },
   -- Right-click: paste
   {
      event = { Down = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      action = act.PasteFrom('Clipboard'),
   },
}

return {
   disable_default_key_bindings = true,
   -- disable_default_mouse_bindings = true,
   leader = { key = 'Space', mods = mod.SUPER_REV },
   keys = keys,
   key_tables = key_tables,
   mouse_bindings = mouse_bindings,
}
