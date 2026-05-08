local wezterm = require('wezterm')

local STATE_FILE = wezterm.config_dir .. '/state.json'

local M = {}

function M.read()
   local f = io.open(STATE_FILE, 'r')
   if not f then return {} end
   local content = f:read('*a')
   f:close()
   if content == '' then return {} end
   local ok, data = pcall(wezterm.json_parse, content)
   if not ok or type(data) ~= 'table' then return {} end
   return data
end

function M.write(data)
   local f = io.open(STATE_FILE, 'w')
   if not f then
      wezterm.log_error('state: failed to write ' .. STATE_FILE)
      return
   end
   f:write(wezterm.json_encode(data))
   f:close()
end

function M.update(key, value)
   local data = M.read()
   data[key] = value
   M.write(data)
end

return M
