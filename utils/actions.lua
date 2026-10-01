---Actions shared by a key binding and its command-palette entry.
---
---`config/bindings.lua` and `events/augment-command-palette.lua` used to build
---their own copy of each of these, and the two copies drifted: labels quoting
---the wrong key, and New Window spawning into a different domain from Alt+n.
---Built once here, a key and its palette entry run the same code.
---
---Building them at require time also matters for the palette: its handler runs
---on every F8, and each `wezterm.action_callback` call registers a new event.
local wezterm = require('wezterm')
local act = wezterm.action
local backdrops = require('utils.backdrops')
local cull = require('utils.cull')
local sessions = require('utils.sessions')
local ssh_hosts = require('utils.ssh-hosts')
local workspaces = require('utils.workspaces')

local M = {}

M.cheatsheet = wezterm.action_callback(function(window, pane)
   local home = wezterm.home_dir:gsub('\\', '/')
   local drive = home:sub(1, 1):lower()
   local unix_home = '/' .. drive .. home:sub(3)
   local script = unix_home .. '/Desktop/GitHub/Hassan-Zbib/wezterm-config/scripts/cheatsheet.py'
   window:perform_action(act.SpawnCommandInNewTab({
      args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '--login', '-c', 'uv run python "' .. script .. '"' },
   }), pane)
end)

M.workspace_hub = wezterm.action_callback(function(window, pane)
   workspaces.hub(window, pane)
end)

M.save_session = wezterm.action_callback(function(window, pane)
   sessions.save(window, pane)
end)

M.ssh_picker = wezterm.action_callback(function(window, pane)
   window:perform_action(act.InputSelector({
      title = 'SSH Hosts',
      choices = ssh_hosts.choices(),
      fuzzy = true,
      fuzzy_description = 'Connect to SSH Host: ',
      action = wezterm.action_callback(function(_inner_window, inner_pane, id)
         if id then
            ssh_hosts.connect(inner_pane, id)
         end
      end),
   }), pane)
end)

M.open_url = act.QuickSelectArgs({
   label = 'open url',
   patterns = {
      '\\((https?://\\S+)\\)',
      '\\[(https?://\\S+)\\]',
      '\\{(https?://\\S+)\\}',
      '<(https?://\\S+)>',
      '\\bhttps?://\\S+[)/a-zA-Z0-9-]+',
   },
   action = wezterm.action_callback(function(window, pane)
      local url = window:get_selection_text_for_pane(pane)
      wezterm.log_info('opening: ' .. url)
      wezterm.open_with(url)
   end),
})

-- Spawns a plain window in the default domain -- deliberately no shell alias,
-- so it does not depend on a shell definition this repo never declares, and
-- not `act.SpawnWindow`, which would follow the current pane's domain.
M.new_window = wezterm.action_callback(function(_window, _pane)
   wezterm.mux.spawn_window({})
end)

-- background controls --
M.random_backdrop = wezterm.action_callback(function(window, _pane)
   backdrops:random(window)
end)

M.prev_category = wezterm.action_callback(function(window, _pane)
   backdrops:prev_category(window)
end)

M.next_category = wezterm.action_callback(function(window, _pane)
   backdrops:next_category(window)
end)

M.browse_backdrops = wezterm.action_callback(function(window, pane)
   if backdrops.focus_on then
      return
   end
   if window:active_key_table() == 'browse_backdrop' then
      return
   end
   backdrops:enter_browse_mode(window)
   cull:begin()
   window:perform_action(act.ActivateKeyTable({
      name = 'browse_backdrop',
      one_shot = false,
      timeout_milliseconds = backdrops.BROWSE_TIMEOUT,
   }), pane)
end)

M.toggle_focus = wezterm.action_callback(function(window, _pane)
   backdrops:toggle_focus(window)
end)

M.toggle_glass = wezterm.action_callback(function(window, _pane)
   backdrops:toggle_glass(window)
end)

M.toggle_auto_rotate = wezterm.action_callback(function(_window, _pane)
   backdrops:toggle_auto_rotate()
end)

-- One pair of keys for "how much shows through behind the text": the backdrop
-- scrim normally (5% steps), the glass tint in focus mode, where no scrim is
-- drawn (10% steps, saved -- backdrops owns that step size).
local function adjust_opacity(window, delta)
   if backdrops.focus_on then
      backdrops:adjust_glass_tint(window, delta)
   else
      backdrops:adjust_overlay_opacity(window, delta)
   end
end

M.overlay_opacity_down = wezterm.action_callback(function(window, _pane)
   adjust_opacity(window, -0.05)
end)

M.overlay_opacity_up = wezterm.action_callback(function(window, _pane)
   adjust_opacity(window, 0.05)
end)

return M
