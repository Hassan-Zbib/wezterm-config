local wezterm = require('wezterm')

local M = {}

M.setup = function()
   wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
      return tab.active_pane.title
   end)
end

return M
