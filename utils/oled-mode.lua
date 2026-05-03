local wezterm = require('wezterm')

---@class OledMode
---@field enabled boolean whether OLED mode is active
local OledMode = {}
OledMode.__index = OledMode

-- Static dimmed palette applied to status bar / tab fg colors when OLED is on.
-- No cycling — a single fixed color reduces burn-in by being lower-luminance
-- than the bright Catppuccin accents, without the render-cycle complexity that
-- caused keymap dispatch issues in combination with focus mode.
local OLED_ACCENT     = '#b4895d' -- dimmed peach
local OLED_ACCENT_DIM = '#6c5238' -- darker variant for separators / inactive

---Initialise the OLED mode controller. State is intentionally not persisted
---across restarts — wezterm always starts with OLED off.
---@private
function OledMode:init()
   return setmetatable({ enabled = false }, self)
end

---Return the static palette table consumed by event handlers.
---@return { accent: string, accent_dim: string }
function OledMode:current_palette()
   return { accent = OLED_ACCENT, accent_dim = OLED_ACCENT_DIM }
end

---Toggle OLED mode on/off. State-only for status bar / tab visuals (event
---handlers read `oled.enabled` on their next natural tick). When focus mode
---is currently on, also repaint focus across all windows so the new OLED
---state takes effect immediately (opacity 0.6 glass off vs 1.0 opaque black
---on). The repaint goes through the same `_set_opt` path Alt+B uses.
---@param window any WezTerm Window from the keybinding callback (unused)
function OledMode:toggle(window)
   self.enabled = not self.enabled

   -- Repaint every window so backdrops' _set_opt re-evaluates OLED-aware
   -- knobs (window opacity, split color). Pick the right bg layer based on
   -- focus state so we don't accidentally swap modes.
   local ok, backdrops = pcall(require, 'utils.backdrops')
   if not ok or not backdrops then return end
   local gui = wezterm.gui
   if not gui then return end
   for _, win in ipairs(gui.gui_windows()) do
      local opts = backdrops.focus_on
         and backdrops:_create_focus_opts()
         or backdrops:_create_opts()
      backdrops:_set_opt(win, opts)
   end
end

---No-op kept callable so existing right-status handler doesn't error.
---@param window any WezTerm Window (unused)
function OledMode:ensure_window(window) end

return OledMode:init()
