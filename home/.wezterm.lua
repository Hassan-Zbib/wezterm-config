-- ============================================================================
-- WezTerm Entry Point
-- ============================================================================
--
-- SETUP: Change the line below to match where you cloned the repo.
local WEZTERM_CONFIG_DIR = wezterm.home_dir .. '/Desktop/GitHub/wezterm-config'
-- ============================================================================

local wezterm = require('wezterm')

package.path = package.path .. ';' .. WEZTERM_CONFIG_DIR .. '/?.lua'
package.path = package.path .. ';' .. WEZTERM_CONFIG_DIR .. '/?/init.lua'

local Config = require('config')
local agent_deck = wezterm.plugin.require('https://github.com/Eric162/wezterm-agent-deck')

require('utils.backdrops')
   :set_images_dir(WEZTERM_CONFIG_DIR .. '/backdrops/')
   :set_images()
   :random()

require('events.left-status').setup()
require('events.right-status').setup()
require('events.tab-title').setup({ hide_active_tab_unseen = false, unseen_icon = 'numbered_box' })
require('events.new-tab-button').setup()
require('events.gui-startup').setup()
require('events.window-title').setup()

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

return config
