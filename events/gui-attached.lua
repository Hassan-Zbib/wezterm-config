local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

-- `wezterm connect` sizes the new window to fit the panes it attaches to, and
-- those keep whatever size the last window gave them. Windows then drops that
-- full-screen-sized window at its cascade offset, so it opens hanging off the
-- right and bottom of the primary screen (measured: 1936x1116 at 156,156 on a
-- 1920x1080 panel). No config option reaches this: `initial_cols`/`initial_rows`
-- lose to the panes, and `--position` moves the window without shrinking it.
-- So once attached, resize it to a share of the primary screen -- whichever
-- screen that is right now -- and centre it there.
--
-- Deferred because `gui-attached` fires before the window has finished
-- negotiating a size with the mux server: resizing at that instant changes the
-- OS window without the new size reaching the panes, leaving them at their old
-- size with the rest painted black. 0s showed that, 0.1s did not; 0.2s is that
-- threshold with margin.
local RESIZE_DELAY_SECS = 0.2
local SCREEN_SHARE = 0.8 -- fraction of the primary screen's width and height

M.setup = function()
   wezterm.on('gui-attached', function(_domain)
      wezterm.time.call_after(RESIZE_DELAY_SECS, function()
         local screen = wezterm.gui.screens().main
         local width = math.floor(screen.width * SCREEN_SHARE)
         local height = math.floor(screen.height * SCREEN_SHARE)
         local x = screen.x + math.floor((screen.width - width) / 2)
         local y = screen.y + math.floor((screen.height - height) / 2)

         local workspace = mux.get_active_workspace()
         for _, window in ipairs(mux.all_windows()) do
            local gui_window = window:get_workspace() == workspace and window:gui_window()
            if gui_window then
               gui_window:set_inner_size(width, height)
               gui_window:set_position(x, y)
            end
         end
      end)
   end)
end

return M
