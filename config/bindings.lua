local wezterm = require('wezterm')
local platform = require('utils.platform')
local backdrops = require('utils.backdrops')
local oled = require('utils.oled-mode')
local ssh_hosts = require('utils.ssh-hosts')
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
   {
      key = 'F5',
      mods = 'NONE',
      action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }),
   },
   {
      key = 'F5',
      mods = 'SHIFT',
      action = act.PromptInputLine({
         description = 'New workspace name:',
         action = wezterm.action_callback(function(window, pane, line)
            if line and line ~= '' then
               window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
            end
         end),
      }),
   },
   {
      key = 'F5',
      mods = 'CTRL',
      action = wezterm.action_callback(function(window, pane)
         local current = window:active_workspace()
         window:perform_action(act.PromptInputLine({
            description = 'Rename workspace "' .. current .. '" to:',
            action = wezterm.action_callback(function(win, p, line)
               if line and line ~= '' then
                  wezterm.mux.rename_workspace(current, line)
                  wezterm.emit('update-status', win, p)
               end
            end),
         }), pane)
      end),
   },
   {
      key = 'F6',
      mods = 'NONE',
      action = wezterm.action_callback(function(window, _pane)
         oled:toggle(window)
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
   -- F9/F10 session bindings are added in home/.wezterm.lua
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
   { key = 'LeftArrow',  mods = mod.SUPER,     action = act.SendString '\u{1b}OH' },
   { key = 'RightArrow', mods = mod.SUPER,     action = act.SendString '\u{1b}OF' },
   { key = 'Backspace',  mods = mod.SUPER,     action = act.SendString '\u{15}' },

   -- copy/paste --
   { key = 'c',          mods = 'CTRL|SHIFT',  action = act.CopyTo('Clipboard') },
   { key = 'v',          mods = 'CTRL|SHIFT',  action = act.PasteFrom('Clipboard') },

   -- tabs --
   -- tabs: spawn+close
   { key = 't',          mods = mod.SUPER,     action = act.SpawnTab('DefaultDomain') },
   { key = 't',          mods = mod.SUPER_REV, action = act.SpawnTab({ DomainName = 'wsl:ubuntu-fish' }) },
   { key = 'w',          mods = mod.SUPER_REV, action = act.CloseCurrentTab({ confirm = false }) },

   -- tabs: navigation
   { key = '[',          mods = mod.SUPER,     action = act.ActivateTabRelative(-1) },
   { key = ']',          mods = mod.SUPER,     action = act.ActivateTabRelative(1) },

   -- workspaces: cycle
   { key = '[',          mods = mod.SUPER_REV, action = act.SwitchWorkspaceRelative(-1) },
   { key = ']',          mods = mod.SUPER_REV, action = act.SwitchWorkspaceRelative(1) },

   -- tab: title
   { key = '0',          mods = mod.SUPER,     action = act.EmitEvent('tabs.manual-update-tab-title') },
   { key = '0',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.reset-tab-title') },

   -- tab: hide tab-bar
   { key = '9',          mods = mod.SUPER,     action = act.EmitEvent('tabs.toggle-tab-bar'), },

   -- tab: flip top <-> bottom
   { key = '8',          mods = mod.SUPER,     action = act.EmitEvent('tabs.toggle-tab-bar-position'), },

   -- window --
   -- window: spawn windows
   {
      key = 'n', mods = mod.SUPER,
      action = wezterm.action_callback(function(_window, _pane)
         local _, new_pane, _ = wezterm.mux.spawn_window({})
         new_pane:send_text('ff\n')
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

   -- file manager --
   { key = 'e', mods = mod.SUPER, action = act.SendString('yy\n') },

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
   { key = 'PageUp',   mods = 'ALT',     action = act.ScrollByLine(-5) },
   { key = 'PageDown', mods = 'ALT',     action = act.ScrollByLine(5) },
   { key = 'PageUp',   mods = 'NONE',    action = act.ScrollByPage(-0.75) },
   { key = 'PageDown', mods = 'NONE',    action = act.ScrollByPage(0.75) },
   { key = 'Home',     mods = 'NONE',    action = act.ScrollToTop },
   { key = 'End',      mods = 'NONE',    action = act.ScrollToBottom },

   -- panes: jump between prompts (requires shell integration)
   { key = 'UpArrow',   mods = 'SHIFT',  action = act.ScrollToPrompt(-1) },
   { key = 'DownArrow', mods = 'SHIFT',  action = act.ScrollToPrompt(1) },

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
   -- resize panes
   {
      key = 'p',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_pane',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
}

-- stylua: ignore
local key_tables = {
   resize_font = {
      { key = 'UpArrow',   action = act.IncreaseFontSize },
      { key = 'DownArrow', action = act.DecreaseFontSize },
      { key = 'r',         action = act.ResetFontSize },
      { key = 'Escape',    action = 'PopKeyTable' },
      { key = 'q',         action = 'PopKeyTable' },
   },
   resize_pane = {
      { key = 'UpArrow',    action = act.AdjustPaneSize({ 'Up', 1 }) },
      { key = 'DownArrow',  action = act.AdjustPaneSize({ 'Down', 1 }) },
      { key = 'LeftArrow',  action = act.AdjustPaneSize({ 'Left', 1 }) },
      { key = 'RightArrow', action = act.AdjustPaneSize({ 'Right', 1 }) },
      { key = 'Escape',     action = 'PopKeyTable' },
      { key = 'q',          action = 'PopKeyTable' },
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
