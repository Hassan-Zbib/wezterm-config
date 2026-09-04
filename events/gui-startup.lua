local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

---Spawn the initial window, unless the mux already has one.
---
---A single launch can fire both `mux-startup` (in the background server) and
---`gui-startup` (in the client that connects to it), so this has to be
---idempotent -- otherwise `wezterm connect mux` produces a duplicate window.
---The workspace name comes from `default_workspace` in config/general.lua.
---@param cmd? table SpawnCommand handed over by the startup event
local function ensure_initial_window(cmd)
   if #mux.all_windows() > 0 then
      return
   end

   local _tab, pane, _window = mux.spawn_window(cmd or {})
   pane:send_text('ff\n')
end

M.setup = function()
   -- Runs inside `wezterm-mux-server`, before any GUI exists. Nothing here may
   -- touch gui_window().
   wezterm.on('mux-startup', function()
      ensure_initial_window(nil)
   end)

   -- Runs for a plain `wezterm start`. Under `wezterm connect mux` the server
   -- has usually already built the window, so this no-ops.
   wezterm.on('gui-startup', function(cmd)
      ensure_initial_window(cmd)
   end)

   -- Fires after gui-startup once a domain is attached, and is the only hook
   -- that runs on the `wezterm connect mux` path with a real GUI window
   -- present -- so maximizing belongs here rather than in the spawn helpers.
   wezterm.on('gui-attached', function(_domain)
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
end

return M
