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

local STATE_FILE = wezterm.config_dir .. '/.oled-mode-state'

---Initialise the OLED mode controller.
---@private
function OledMode:init()
   return setmetatable({ enabled = false }, self)
end

---Return the static palette table consumed by event handlers.
---@return { accent: string, accent_dim: string }
function OledMode:current_palette()
   return { accent = OLED_ACCENT, accent_dim = OLED_ACCENT_DIM }
end

---Write current state to disk.
function OledMode:save()
   local data = wezterm.json_encode({ enabled = self.enabled })
   local file = io.open(STATE_FILE, 'w')
   if not file then
      wezterm.log_error('OLED mode: failed to write state file: ' .. STATE_FILE)
      return
   end
   file:write(data)
   file:close()
end

---Read state from disk and apply to the singleton fields.
function OledMode:load()
   local file = io.open(STATE_FILE, 'r')
   if not file then return end
   local content = file:read('*a')
   file:close()
   if content == '' then return end
   local ok, data = pcall(wezterm.json_parse, content)
   if not ok or type(data) ~= 'table' then return end
   self.enabled = data.enabled == true
end

---Toggle OLED mode on/off. PURELY state-only: never calls
---set_config_overrides, never touches backdrops, never emits events. Event
---handlers (right-status, left-status, tab-title) read `oled.enabled` and
---apply the static dimmed palette on their next natural tick.
---@param window any WezTerm Window (unused)
function OledMode:toggle(window)
   self.enabled = not self.enabled
   self:save()
end

---No-op kept callable so existing right-status handler doesn't error.
---@param window any WezTerm Window (unused)
function OledMode:ensure_window(window) end

return OledMode:init()
