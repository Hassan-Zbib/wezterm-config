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

---Toggle OLED mode on/off. PURELY state-only: never calls
---set_config_overrides, never touches backdrops, never emits events, never
---persists. Event handlers (right-status, left-status, tab-title) read
---`oled.enabled` and apply the static dimmed palette on their next natural
---tick.
---@param window any WezTerm Window (unused)
function OledMode:toggle(window)
   self.enabled = not self.enabled
end

---No-op kept callable so existing right-status handler doesn't error.
---@param window any WezTerm Window (unused)
function OledMode:ensure_window(window) end

return OledMode:init()
