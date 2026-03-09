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

return config
