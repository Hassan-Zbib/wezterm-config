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

local backdrops = require('utils.backdrops')
local palette = require('colors.palette')
backdrops
   -- Focus mode paints a solid background. Uses `mantle` (#050505), not
   -- `crust` (#000000): pure black makes glyphs bloom -- the exact effect
   -- palette.lua warns about -- and #050505 is what Warp renders.
   :set_focus(palette.mantle)
   :set_images_dir(wezterm.home_dir .. '/Desktop/GitHub/Hassan-Zbib/wezterm-config/backdrops/')

-- `wezterm.gui` is nil inside `wezterm-mux-server`, and `:set_images()` needs
-- the GUI's main coroutine for `wezterm.glob`. Throwing there makes WezTerm
-- silently discard the ENTIRE config for its built-in defaults, with nothing in
-- the server log -- the symptom is `wezterm connect mux` handing you cmd.exe
-- panes in a "default" workspace. Backgrounds are GUI-only anyway.
if wezterm.gui then
   backdrops:set_images():random()
end

require('events.left-status').setup()
require('events.right-status').setup()
require('events.tab-title').setup({ hide_active_tab_unseen = false, unseen_icon = 'numbered_box' })
require('events.new-tab-button').setup()
require('events.window-title').setup()
require('events.augment-command-palette').setup()

local config = Config:init()
   :append(require('config.appearance'))
   :append(require('config.bindings'))
   :append(require('config.domains'))
   :append(require('config.fonts'))
   :append(require('config.general'))
   :append(require('config.launch')).options

return config
