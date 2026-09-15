local wezterm = require('wezterm')
local platform = require('utils.platform')

local options = {
   default_prog = {},
   launch_menu = {},
}

if platform.is_win then
   -- zsh is installed INTO the Git for Windows tree by scripts/install-zsh.sh,
   -- so zsh.exe sits beside msys-2.0.dll and shares Git's MSYS root and /etc.
   -- Git Bash stays available from the launcher (F3). A Git upgrade can wipe
   -- it, but install-zsh.sh is idempotent and ./install re-runs it.
   local zsh = 'C:\\Program Files\\Git\\usr\\bin\\zsh.exe'
   local bash = 'C:\\Program Files\\Git\\bin\\bash.exe'

   -- MSYSTEM is normally set by Git's own bash.exe launcher, which WezTerm
   -- bypasses when it spawns zsh directly. Without it /etc/profile falls back to
   -- MSYSTEM=MSYS and drops /mingw64/bin from PATH -- still true with zsh inside
   -- the Git tree, verified by reading MSYSTEM back from a clean `zsh -l`.
   --
   -- PATH is deliberately NOT extended with Git's usr/bin: the loader now finds
   -- msys-2.0.dll beside zsh.exe, so the MSYS tools there (find.exe, sort.exe)
   -- no longer shadow the Windows ones for everything WezTerm spawns.
   options.set_environment_variables = {
      MSYSTEM = 'MINGW64',
   }

   options.default_prog = { zsh, '-l' }
   options.launch_menu = {
      { label = 'Zsh', args = { zsh, '-l' } },
      { label = 'PowerShell 7', args = { 'pwsh', '-NoLogo' } },
      { label = 'Git Bash', args = { bash, '--login' } },
      { label = 'WSL Ubuntu', args = { 'wsl.exe', '-d', 'Ubuntu' } },
      { label = 'Command Prompt', args = { 'cmd' } },
   }
elseif platform.is_mac then
   options.default_prog = { '/opt/homebrew/bin/fish', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { '/opt/homebrew/bin/fish', '-l' } },
      { label = 'Nushell', args = { '/opt/homebrew/bin/nu', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
elseif platform.is_linux then
   options.default_prog = { 'fish', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { 'fish', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
end

return options
