local wezterm = require('wezterm')
local titles = require('utils.titles')

local M = {}

M.setup = function()
   wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
      return titles.clean(tab.active_pane.title)
   end)
end

return M
