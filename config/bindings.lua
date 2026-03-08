local wezterm = require('wezterm')
local platform = require('utils.platform')
local backdrops = require('utils.backdrops')
local sessions = require('utils.sessions')
local ssh_hosts = require('utils.ssh-hosts')
local act = wezterm.action

local mod = {}

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
         local script = unix_home .. '/Desktop/GitHub/wezterm-config/scripts/cheatsheet.sh'
         window:perform_action(act.SpawnCommandInNewTab({
            args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '--login', '-c', script },
         }), pane)
      end),
   },
   { key = 'F2', mods = 'NONE', action = act.ActivateCommandPalette },
   { key = 'F3', mods = 'NONE', action = act.ShowLauncher },
   { key = 'F4', mods = 'NONE', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },
   {
      key = 'F5',
      mods = 'NONE',
      action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }),
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
   { key = 'F8', mods = 'NONE', action = 'ActivateCopyMode' },
   {
      key = 'F9',
      mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
         sessions.save(window, pane)
      end),
   },
   {
      key = 'F10',
      mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
         window:perform_action(act.InputSelector({
            title = 'Restore Session',
            choices = sessions.choices(),
            fuzzy = true,
            fuzzy_description = 'Select Session: ',
            action = wezterm.action_callback(function(inner_window, inner_pane, id)
               if id then
                  sessions.restore(inner_window, inner_pane, id)
               end
            end),
         }), pane)
      end),
   },
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
   { key = '[',          mods = mod.SUPER_REV, action = act.MoveTabRelative(-1) },
   { key = ']',          mods = mod.SUPER_REV, action = act.MoveTabRelative(1) },

   -- tab: title
   { key = '0',          mods = mod.SUPER,     action = act.EmitEvent('tabs.manual-update-tab-title') },
   { key = '0',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.reset-tab-title') },

   -- tab: hide tab-bar
   { key = '9',          mods = mod.SUPER,     action = act.EmitEvent('tabs.toggle-tab-bar'), },

   -- window --
   -- window: spawn windows
   { key = 'n',          mods = mod.SUPER,     action = act.SpawnWindow },

   -- window: zoom window
   {
      key = '-',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local dimensions = window:get_dimensions()
         if dimensions.is_full_screen then
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
         if dimensions.is_full_screen then
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
         window:maximize()
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
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_back(window)
      end),
   },
   {
      key = [[.]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_forward(window)
      end),
   },
   {
      key = [[/]],
      mods = mod.SUPER_REV,
      action = act.InputSelector({
         title = 'InputSelector: Select Background',
         choices = backdrops:choices(),
         fuzzy = true,
         fuzzy_description = 'Select Background: ',
         action = wezterm.action_callback(function(window, _pane, idx)
            if not idx then
               return
            end
            ---@diagnostic disable-next-line: param-type-mismatch
            backdrops:set_img(window, tonumber(idx))
         end),
      }),
   },
   {
      key = 'b',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:toggle_focus(window)
      end)
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

   -- panes: scroll pane
   { key = 'u',        mods = mod.SUPER, action = act.ScrollByLine(-5) },
   { key = 'd',        mods = mod.SUPER, action = act.ScrollByLine(5) },
   { key = 'PageUp',   mods = 'NONE',    action = act.ScrollByPage(-0.75) },
   { key = 'PageDown', mods = 'NONE',    action = act.ScrollByPage(0.75) },
   { key = 'End',      mods = 'NONE',    action = act.ScrollToBottom },

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
}

local mouse_bindings = {
   -- Ctrl-click will open the link under the mouse cursor
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
   },
   -- Right-click: copy if text is selected, paste otherwise
   {
      event = { Down = { streak = 1, button = 'Right' } },
      mods = 'NONE',
      action = wezterm.action_callback(function(window, pane)
         local has_selection = window:get_selection_text_for_pane(pane) ~= ''
         if has_selection then
            window:perform_action(act.CopyTo('ClipboardAndPrimarySelection'), pane)
         else
            window:perform_action(act.PasteFrom('Clipboard'), pane)
         end
      end),
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
