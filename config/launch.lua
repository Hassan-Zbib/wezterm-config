local wezterm = require('wezterm')
local platform = require('utils.platform')

local options = {
   default_prog = {},
   launch_menu = {},
}

if platform.is_win then
   -- zsh is installed portably under ~/.local/zsh by scripts/install-zsh.sh,
   -- so it survives Git for Windows updates. Git Bash stays available from the
   -- launcher (F3); swap default_prog back to it to revert.
   local zsh = wezterm.home_dir .. '\\.local\\zsh\\usr\\bin\\zsh.exe'
   local bash = 'C:\\Program Files\\Git\\bin\\bash.exe'

   -- zsh.exe lives outside the Git for Windows tree, so at process-creation
   -- time the Windows loader cannot resolve msys-2.0.dll & friends unless
   -- Git's usr/bin is on PATH -- without it zsh dies with 0xC0000135
   -- (STATUS_DLL_NOT_FOUND) before running a single line of config.
   --
   -- Appended, never prepended: the MSYS tools in that directory (find.exe,
   -- sort.exe, ...) would otherwise shadow the Windows ones for every program
   -- WezTerm spawns. Copying the DLLs next to zsh.exe instead would be worse
   -- -- two msys-2.0.dll instances at different paths put parent and child
   -- processes in separate MSYS worlds and break fork/exec between them.
   -- Once zsh starts, /etc/profile rebuilds PATH normally.
   --
   -- MSYSTEM is normally set by Git for Windows' own bash.exe launcher, which
   -- WezTerm bypasses when it spawns zsh directly. Without it /etc/profile
   -- falls back to MSYSTEM=MSYS and leaves /mingw64/bin off PATH entirely.
   options.set_environment_variables = {
      PATH = os.getenv('PATH') .. ';C:\\Program Files\\Git\\usr\\bin',
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
