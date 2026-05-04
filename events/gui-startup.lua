local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local _, pane, window = mux.spawn_window(cmd or {})
      mux.rename_workspace('default', 'main')
      window:gui_window():maximize()
      pane:send_text('ff\n')
   end)
end

return M
