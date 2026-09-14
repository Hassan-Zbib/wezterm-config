local wezterm = require('wezterm')
local platform = require('utils.platform')

local options = {
   default_prog = {},
   launch_menu = {},
}

if platform.is_win then
   -- zsh is installed INTO the Git for Windows tree by scripts/install-zsh.sh
   -- (--system), so zsh.exe sits beside msys-2.0.dll and shares Git's MSYS
   -- root, mount table and /etc. Git Bash stays available from the launcher
   -- (F3); swap default_prog back to it to revert.
   --
   -- The trade-off is that a Git for Windows upgrade can wipe files added under
   -- C:\Program Files\Git. install-zsh.sh is idempotent and ./install re-runs
   -- it, so recovering is a matter of running the installer again.
   local zsh = 'C:\\Program Files\\Git\\usr\\bin\\zsh.exe'
   local bash = 'C:\\Program Files\\Git\\bin\\bash.exe'

   -- MSYSTEM is normally set by Git for Windows' own bash.exe launcher, which
   -- WezTerm bypasses when it spawns zsh directly. Without it /etc/profile
   -- falls back to MSYSTEM=MSYS and leaves /mingw64/bin off PATH entirely.
   -- That is still true with zsh inside the Git tree -- verified by launching
   -- `zsh -l` from a clean shell and reading MSYSTEM back as MSYS -- so this
   -- assignment has to stay.
   --
   -- PATH used to be extended here with Git's usr/bin: a zsh.exe living outside
   -- the Git tree could not resolve msys-2.0.dll and died with 0xC0000135
   -- (STATUS_DLL_NOT_FOUND) before running a single line of config. The
   -- --system install removes that need entirely -- the Windows loader finds
   -- the DLL next to the executable -- so PATH is left alone, and the MSYS
   -- tools in that directory (find.exe, sort.exe, ...) no longer shadow the
   -- Windows ones for every program WezTerm spawns.
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
