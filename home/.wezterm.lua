-- ============================================================================
-- WezTerm Configuration
-- References: C:\Users\Hasan\Desktop\GitHub\wezterm-config
-- Repo: https://github.com/KevinSilvester/wezterm-config
-- ============================================================================

local wezterm = require('wezterm')

-- Add the wezterm-config repo to Lua's package path
local config_path = wezterm.home_dir .. '/Desktop/GitHub/wezterm-config'
package.path = package.path .. ';' .. config_path .. '/?.lua'
package.path = package.path .. ';' .. config_path .. '/?/init.lua'

-- Load and return the config from the repo
local Config = require('config')
local sessions = require('utils.sessions')
local agent_deck = wezterm.plugin.require('https://github.com/Eric162/wezterm-agent-deck')

require('utils.backdrops')
   -- :set_focus('#000000')
   :set_images_dir(wezterm.home_dir .. '/Desktop/GitHub/wezterm-config/backdrops/')
   :set_images()
   :random()

require('events.left-status').setup()
require('events.right-status').setup()
require('events.tab-title').setup({ hide_active_tab_unseen = false, unseen_icon = 'numbered_box' })
require('events.new-tab-button').setup()
require('events.gui-startup').setup()
require('events.window-title').setup()
require('events.augment-command-palette').setup()

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

-- Toggle agent deck notifications (F6)
table.insert(config.keys, {
   key = 'F6',
   mods = 'NONE',
   action = wezterm.action_callback(function(window, _pane)
      local cfg = agent_deck.get_config()
      cfg.notifications.enabled = not cfg.notifications.enabled
      local status = cfg.notifications.enabled and 'ON' or 'OFF'
      window:toast_notification('Agent Deck', 'Notifications ' .. status, nil, 3000)
   end),
})

-- Session save/restore with auto-save toggle
local session_auto_save = { enabled = false, interval = 900 }

local function session_auto_save_loop()
   wezterm.time.call_after(session_auto_save.interval, function()
      if session_auto_save.enabled then
         local mux = wezterm.mux
         local win = mux.get_active_workspace()
         for _, mux_win in ipairs(mux.all_windows()) do
            local gui_win = mux_win:gui_window()
            if gui_win then
               local pane = mux_win:active_pane()
               sessions.save(gui_win, pane)
               break
            end
         end
      end
      session_auto_save_loop()
   end)
end
session_auto_save_loop()

_G.session_auto_save = session_auto_save

-- Shift+F9: Toggle auto-save
table.insert(config.keys, {
   key = 'F9',
   mods = 'SHIFT',
   action = wezterm.action_callback(function(win, _pane)
      session_auto_save.enabled = not session_auto_save.enabled
      local status = session_auto_save.enabled and 'ON' or 'OFF'
      win:toast_notification('Sessions', 'Auto-save ' .. status, nil, 3000)
   end),
})

-- F9: Save session (auto-named: workspace-tab-datetime)
table.insert(config.keys, {
   key = 'F9',
   mods = 'NONE',
   action = wezterm.action_callback(function(win, pane)
      sessions.save(win, pane)
   end),
})

-- Shift+F10: Save session with custom name
table.insert(config.keys, {
   key = 'F10',
   mods = 'SHIFT',
   action = wezterm.action_callback(function(win, pane)
      sessions.save_with_name(win, pane)
   end),
})

-- F10: Restore session (fuzzy finder)
table.insert(config.keys, {
   key = 'F10',
   mods = 'NONE',
   action = wezterm.action_callback(function(win, pane)
      win:perform_action(wezterm.action.InputSelector({
         title = 'Restore Session',
         choices = sessions.choices(),
         fuzzy = true,
         fuzzy_description = 'Select Session: ',
         action = wezterm.action_callback(function(inner_win, inner_pane, id)
            if id then
               sessions.restore(inner_win, inner_pane, id)
            end
         end),
      }), pane)
   end),
})

-- Shift+F10+Ctrl: Delete a saved session
table.insert(config.keys, {
   key = 'F10',
   mods = 'CTRL',
   action = wezterm.action_callback(function(win, pane)
      sessions.delete(win, pane)
   end),
})

return config
