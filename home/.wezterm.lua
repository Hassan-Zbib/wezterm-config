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

-- `wezterm.gui` is nil inside `wezterm-mux-server`, and `:set_images()` calls
-- `wezterm.glob`, which needs the GUI's main coroutine. Running it in the mux
-- server throws while the config is still being evaluated, and WezTerm answers
-- by silently discarding the ENTIRE config and falling back to its built-in
-- defaults -- no error in the server log. Symptom: `wezterm connect mux` hands
-- you cmd.exe panes in a workspace called "default" instead of Git Bash in
-- "main". Backgrounds are a GUI-only concern anyway, so gate them here.
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
