local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

-- Maximizing has to be deferred on the cold path. `gui-attached` fires before
-- the GUI window has finished negotiating a size with the freshly spawned mux
-- server, and maximizing at that instant resizes the OS window without the new
-- dimensions ever reaching the remote pane: you get a full-screen window
-- rendering an 80x25 pane with the remainder painted black.
local MAXIMIZE_DELAY_SECS = 1

---There are deliberately no `gui-startup` or `mux-startup` handlers here.
---
---`wezterm connect` -- our default, see config/domains.lua -- always spawns a
---tab of its own, and never fires `gui-startup` at all. `wezterm start` falls
---back to WezTerm's own default window. Both paths already produce exactly one
---window, so anything spawned here is a duplicate; doing so is what previously
---left the GUI stuck on "Checking server version" owning two panes.
M.setup = function()
   wezterm.on('gui-attached', function(_domain)
      wezterm.time.call_after(MAXIMIZE_DELAY_SECS, function()
         local workspace = mux.get_active_workspace()
         for _, window in ipairs(mux.all_windows()) do
            if window:get_workspace() == workspace then
               local gui_window = window:gui_window()
               if gui_window then
                  gui_window:maximize()
               end
            end
         end
      end)
   end)
end

return M
