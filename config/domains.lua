local platform = require('utils.platform')

local options = {
   -- ref: https://wezfurlong.org/wezterm/config/lua/SshDomain.html
   ssh_domains = {},

   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   unix_domains = {},

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   wsl_domains = {},
}

if platform.is_win then
   -- Simple WSL domain - uses default WSL user
   options.wsl_domains = {
      {
         name = 'WSL:Ubuntu',
         distribution = 'Ubuntu',
         -- Omitting username/default_cwd lets WezTerm use WSL defaults
         default_prog = { 'bash', '-l' },
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
