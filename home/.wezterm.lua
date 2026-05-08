-- ============================================================================
-- WezTerm Configuration
-- References: C:\Users\hassa\Desktop\GitHub\Hassan-Zbib\wezterm-config
-- Repo: https://github.com/KevinSilvester/wezterm-config
-- ============================================================================

local wezterm = require('wezterm')

-- Add the wezterm-config repo to Lua's package path
local config_path = wezterm.home_dir .. '/Desktop/GitHub/Hassan-Zbib/wezterm-config'
package.path = package.path .. ';' .. config_path .. '/?.lua'
package.path = package.path .. ';' .. config_path .. '/?/init.lua'

-- Load and return the config from the repo
local Config = require('config')
local sessions = require('utils.sessions')

local backdrops = require('utils.backdrops')
backdrops
   :set_images_dir(wezterm.home_dir .. '/Desktop/GitHub/Hassan-Zbib/wezterm-config/backdrops/')
   :set_images()
   :random()

require('utils.oled-mode')

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
