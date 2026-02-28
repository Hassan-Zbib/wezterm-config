local wezterm = require('wezterm')

local M = {}

M.setup = function()
   wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
      -- Key binding hints
      local hints = 'F1:copy F2:palette F3:launcher Alt+f:search | Alt+t:tab Alt+[/]:switch Alt+0:rename | Alt+\\:vsplit Alt+Ctrl+\\:hsplit Alt+w:close Alt+Ctrl+p:swap | End:bottom | Alt+,:prev-bg Alt+.:next-bg Alt+b:no-bg'

      -- Get current tab title or use default
      local title = tab.active_pane.title
      if title and #title > 0 then
         return hints .. ' | ' .. title
      else
         return hints
      end
   end)
end

return M
