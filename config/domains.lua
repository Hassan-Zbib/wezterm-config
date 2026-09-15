local platform = require('utils.platform')

local options = {
   -- ref: https://wezfurlong.org/wezterm/config/lua/SshDomain.html
   ssh_domains = {},

   -- The persistent multiplexer. Panes here are owned by a background
   -- `wezterm-mux-server`, not the GUI, so closing or crashing the window leaves
   -- long-lived agents running. Despite the option name, this is a named pipe on
   -- Windows, not a unix socket.
   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   unix_domains = {
      { name = 'mux' },
   },

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   wsl_domains = {},

   -- Make a bare `wezterm` behave as `wezterm connect mux`, so the GUI is a thin
   -- client of the server above rather than hosting its own mux.
   --
   -- Escape hatches: `wezterm start` (plain local window), Alt+Ctrl+T
   -- (throwaway local tab), Alt+Ctrl+M (domain manager, incl. mux restart).
   --
   -- Ctrl+Shift+R reloads the GUI config only -- the mux server keeps the config
   -- it booted with, so `default_prog` and domain changes need a restart.
   --
   -- No `gui-startup`/`mux-startup` handlers, deliberately: `wezterm connect`
   -- spawns its own tab and never fires `gui-startup`, and `wezterm start` falls
   -- back to the default window. Both already yield exactly one window, so a
   -- startup event would only ever duplicate it.
   default_gui_startup_args = { 'connect', 'mux' },
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
