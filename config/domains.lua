local platform = require('utils.platform')

local options = {
   -- ref: https://wezfurlong.org/wezterm/config/lua/SshDomain.html
   ssh_domains = {},

   -- The persistent multiplexer. Panes spawned here are owned by a background
   -- `wezterm-mux-server` process rather than by the GUI, so closing (or
   -- crashing) the window leaves everything running -- which is the whole point
   -- for long-lived CLI agents. Despite the option name this is backed by a
   -- named pipe on Windows, not a unix socket.
   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   unix_domains = {
      { name = 'mux' },
   },

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   wsl_domains = {},

   -- Make a bare `wezterm` behave as `wezterm connect mux`, so the GUI is a thin
   -- client of the server above instead of hosting its own private mux.
   --
   -- Escape hatches, in order of severity:
   --   `wezterm start`  -- plain local window, ignores the mux entirely
   --   Alt+Ctrl+T       -- throwaway local tab from inside a mux window
   --   Alt+Ctrl+M       -- domain manager, including "restart mux server"
   --
   -- Caveat worth remembering: Ctrl+Shift+R reloads the GUI's config, but the
   -- mux server keeps the config it booted with. Changes to `default_prog`,
   -- domains, or the mux-side startup event need the server restarted.
   -- `--position` pins the first window to the top-left of the main monitor.
   -- Without it the window lands wherever Windows decides, which combined with
   -- the maximize in events/gui-startup.lua read as "opens somewhere odd, then
   -- jumps". Paired with `initial_cols`/`initial_rows` in config/appearance.lua
   -- the window now starts at roughly its final size and place.
   default_gui_startup_args = { 'connect', 'mux', '--position', 'main:0,0' },
}

if platform.is_win then
   -- Linux tabs, opt-in per tab (Alt+Ctrl+Shift+T, or the Alt+Ctrl+M manager).
   -- Windows/Git Bash stays the default for every ordinary tab -- see
   -- `default_prog` in config/launch.lua.
   --
   -- These panes are owned by the mux server like any other, so a WSL tab
   -- survives closing the window just as a Git Bash one does.
   options.wsl_domains = {
      {
         name = 'WSL:Ubuntu',
         distribution = 'Ubuntu',
         -- bash, because that is all this distro has: neither fish nor zsh is
         -- installed. To switch, install it inside WSL first
         -- (`sudo apt install fish`) and then change this line -- pointing the
         -- domain at a missing binary makes the tab fail to spawn.
         default_prog = { 'bash', '-l' },
         -- Without this a WSL tab opens in /mnt/c/Users/hassa: WezTerm falls
         -- back to the Windows home and translates it onto the 9p mount. That
         -- path is both the wrong place to be and markedly slower than ext4,
         -- and cwd is NOT inherited from the pane you spawned from, so it
         -- happens every time. Land in the Linux home instead; `cd /mnt/c/...`
         -- when you deliberately want the Windows side.
         default_cwd = '/home/hassan',
      },
   }

   -- Add SSH domains here if you need to connect to remote servers
   -- Example:
   -- options.ssh_domains = {
   --    {
   --       name = 'my-server',
   --       remote_address = 'server.example.com',
   --       username = 'your-username',
   --    },
   -- }
end

return options
