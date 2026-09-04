local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

-- Written by the mux server when it boots, consumed by the first GUI that
-- attaches to it. Lives in WezTerm's state dir (next to `sock`) rather than the
-- repo so it never shows up in git status.
local FRESH_MARKER = wezterm.home_dir .. '/.local/share/wezterm/mux-session-fresh'

-- How long after a server boot an attach still counts as "the launch that
-- started it". Bounds the blast radius if a marker is ever left behind: a stale
-- one cannot make us type into a session that has been running for hours.
local FRESH_WINDOW_SECS = 120

-- Grace period before greeting, to let the connect-spawned login shell finish
-- sourcing its profile. Git Bash `--login` here is not instant.
local GREET_DELAY_SECS = 3

---Which startup event fires depends entirely on how WezTerm was launched:
---
---  `wezterm` (our default -> `connect mux`)  mux-startup, then gui-attached
---  reopening against a live server           gui-attached only
---  `wezterm start` (the escape hatch)        gui-startup, then gui-attached
---
---Critically, `gui-startup` does NOT fire on the connect path, and the connect
---itself always spawns one tab in the domain. So `mux-startup` must NOT create a
---window: if it does, you get that tab *plus* the connect's tab. That is the
---duplicate that left the GUI sitting on "Checking server version".
M.setup = function()
   -- Server side. Records that this mux is brand new; deliberately spawns
   -- nothing -- see the note above.
   wezterm.on('mux-startup', function()
      local f = io.open(FRESH_MARKER, 'w')
      if f then
         f:write(tostring(os.time()))
         f:close()
      end
   end)

   -- Only reached by `wezterm start`, where no mux server is involved and
   -- nothing else will create the window for us.
   wezterm.on('gui-startup', function(cmd)
      if #mux.all_windows() > 0 then
         return
      end

      local _tab, pane, _window = mux.spawn_window(cmd or {})
      pane:send_text('ff\n')
   end)

   -- Fires on every path once a domain is attached, and is the first point at
   -- which a real GUI window exists.
   wezterm.on('gui-attached', function(domain)
      local workspace = mux.get_active_workspace()
      for _, window in ipairs(mux.all_windows()) do
         if window:get_workspace() == workspace then
            local gui_window = window:gui_window()
            if gui_window then
               gui_window:maximize()
            end
         end
      end

      M.greet_fresh_mux(domain)
   end)
end

---Run the `ff` greeting, but only for a mux session this launch actually
---created. Reattaching to a server that was already running must stay silent --
---otherwise `ff` gets typed into whatever was left at a prompt, which for this
---setup is frequently a CLI agent waiting on input.
---@param domain any MuxDomain handed over by `gui-attached`
function M.greet_fresh_mux(domain)
   local ok, name = pcall(function()
      return domain:name()
   end)
   if not ok or name ~= 'mux' then
      return
   end

   local f = io.open(FRESH_MARKER, 'r')
   if not f then
      return
   end
   local stamp = tonumber(f:read('*a') or '') or 0
   f:close()

   -- Consume it either way: a marker old enough to be rejected is stale and
   -- should not sit around waiting to mislead the next attach.
   os.remove(FRESH_MARKER)

   if os.time() - stamp > FRESH_WINDOW_SECS then
      return
   end

   -- The tab on this path is created by the connect itself, and its login shell
   -- is often still starting when `gui-attached` fires -- text written that
   -- early is written into a pty nobody is draining yet and is simply lost.
   -- Wait for the shell to come up before greeting it.
   wezterm.time.call_after(GREET_DELAY_SECS, function()
      local windows = mux.all_windows()
      if #windows ~= 1 then
         return
      end

      local tab = windows[1]:active_tab()
      local pane = tab and tab:active_pane()
      if pane then
         pane:send_text('ff\n')
      end
   end)
end

return M
