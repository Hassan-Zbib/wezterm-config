-- =============================================================================
-- utils/peal.lua — peal-daemon notification helper
--
-- Sends notifications via the local peal-daemon HTTP API.
-- Falls back to wezterm.toast_notification() when the daemon is offline.
--
-- Usage:
--   local peal = require('utils.peal')
--   peal.notify(window, 'My App', 'Something happened', { urgency = 'normal' })
--
-- The module caches the last known daemon state so update-status can read it
-- without ever making a network call.
-- =============================================================================

local wezterm = require('wezterm')
local platform = require('utils.platform')

local M = {}

-- Port the peal daemon listens on. Change if you customised [server] port.
M.port = 29876

-- How long (seconds) to skip peal after a failed connect before retrying.
local RETRY_AFTER = 15

-- curl connection timeout in seconds — fast enough to not block the UI.
local CONNECT_TIMEOUT = '0.5'

-- Internal state — updated by notify(), never exposed directly.
local _state = {
   last_ok   = 0, -- epoch of last successful peal send
   last_fail = 0, -- epoch of last failed peal send
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function curl_exe()
   return platform.is_win and 'curl.exe' or 'curl'
end

--- Minimal JSON encoder for flat string/number/boolean tables.
local function json_encode(t)
   local parts = {}
   for k, v in pairs(t) do
      local encoded
      if type(v) == 'string' then
         encoded = '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
      elseif type(v) == 'number' then
         encoded = string.format('%.0f', v)
      elseif type(v) == 'boolean' then
         encoded = tostring(v)
      end
      if encoded then
         table.insert(parts, '"' .. k .. '":' .. encoded)
      end
   end
   return '{' .. table.concat(parts, ',') .. '}'
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Send a notification.
---
---Tries peal first. If the daemon is offline (or recently failed) it falls
---back to window:toast_notification() immediately — no long wait.
---
---@param window      any     WezTerm window object (used for toast fallback)
---@param app_name    string  Shown as the source app in the popup
---@param summary     string  Title / one-line message
---@param opts?       table   { body?:string, urgency?:string, expire_ms?:number }
---@return boolean            true = sent via peal, false = toast fallback used
M.notify = function(window, app_name, summary, opts)
   opts = opts or {}
   local now = os.time()

   local function fallback()
      window:toast_notification(app_name, summary, nil, opts.expire_ms or 4000)
   end

   -- Skip peal while we know it's down, to avoid blocking the event loop.
   if _state.last_fail > _state.last_ok and (now - _state.last_fail) < RETRY_AFTER then
      fallback()
      return false
   end

   local payload = { app_name = app_name, summary = summary }
   if opts.body      then payload.body      = opts.body      end
   if opts.urgency   then payload.urgency   = opts.urgency   end
   if opts.expire_ms then payload.expire_ms = opts.expire_ms end

   local ok = wezterm.run_child_process({
      curl_exe(),
      '-s', '-f', '-X', 'POST',
      '-H', 'Content-Type: application/json',
      '-d', json_encode(payload),
      '--connect-timeout', CONNECT_TIMEOUT,
      '--max-time', '1',
      'http://127.0.0.1:' .. M.port .. '/notify',
   })

   if ok then
      _state.last_ok = now
      return true
   else
      _state.last_fail = now
      fallback()
      return false
   end
end

---Returns the last known daemon state without making any network call.
---Safe to call from update-status every second.
---
---@return 'online'|'offline'|'unknown'
M.cached_status = function()
   if _state.last_ok == 0 and _state.last_fail == 0 then
      return 'unknown'
   end
   if _state.last_ok >= _state.last_fail then
      return 'online'
   end
   return 'offline'
end

return M
