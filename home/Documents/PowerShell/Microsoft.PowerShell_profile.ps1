# ============================================================
# PowerShell Profile — WezTerm Shell Integration
# ============================================================
# Managed by dotbot — run ./install from the repo to symlink.
# ============================================================

# ---- SHLVL ----
# SHLVL is a POSIX convention: every shell increments the value it inherits, so
# you can tell how many shells deep you are. PowerShell does not implement it.
# It inherits the parent's value and passes it on unchanged, which silently
# breaks the chain for everything below it:
#
#   zsh(1) -> pwsh        showed 1, should be 2
#   zsh(1) -> pwsh -> zsh showed 2, should be 3
#
# Incrementing it here makes pwsh behave like bash and zsh do. When SHLVL is
# absent entirely -- pwsh opened directly as the first shell in a tab -- this
# yields 1, matching what zsh and bash report in the same situation.
#
# Note this also fires for non-interactive `pwsh -Command ...` invocations,
# which is correct and matches bash/zsh: those really are child shells.
# `pwsh -NoProfile` skips it, so tooling that bypasses the profile is unaffected.
$__shlvl = 0
if ($env:SHLVL) { [void][int]::TryParse($env:SHLVL, [ref]$__shlvl) }
$env:SHLVL = $__shlvl + 1
Remove-Variable __shlvl

# ---- winget ----
function winget { winget.exe @args --accept-source-agreements --accept-package-agreements }

# ---- PSReadLine ----
# Use audible bell (system beep) instead of the default visual flash
Set-PSReadLineOption -BellStyle Audible

# ---- Starship Prompt ----
Invoke-Expression (&starship init powershell)

# ---- WezTerm Shell Integration ----
# Wrap starship's prompt to add OSC 7 (CWD) and OSC 133 (prompt markers)
# so WezTerm can track the working directory and prompt boundaries.
# Skip under Warp: it runs its own prompt/Blocks integration (Warpify), and
# these duplicate OSC markers corrupt Warp's command Blocks.
if ($env:TERM_PROGRAM -ne "WarpTerminal") {
    $__starshipPrompt = $function:prompt

    function prompt {
        $esc = [char]27
        $bel = [char]7

        # OSC 133;D — mark end of previous command output
        [Console]::Write("${esc}]133;D${bel}")

        # OSC 7 — report current working directory
        $cwd = (Get-Location).Path.Replace('\', '/')
        if ($cwd -match '^([A-Z]):(.*)') {
            $cwd = '/' + $Matches[1].ToLower() + $Matches[2]
        }
        [Console]::Write("${esc}]7;file://localhost${cwd}${bel}")

        # OSC 133;A — mark prompt start
        [Console]::Write("${esc}]133;A${bel}")

        # Run starship prompt
        & $__starshipPrompt
    }
}

# ---- ~/bin on PATH ----
# Strip any inherited copies of ~/bin (bash's .bashrc prepends it, and a
# parent bash session leaks those into PowerShell when Claude Code shells
# pwsh), then append exactly once. Extensionless bash wrappers in ~/bin
# (e.g. the 'git' shim) must NOT come before real .exe's — PowerShell can't
# execute extensionless files and would fall back to the "Open With" picker.
$binPath = "$HOME\bin"
$env:PATH = (($env:PATH -split ';' | Where-Object { $_ -and $_ -ine $binPath }) -join ';') + ";$binPath"

# ---- zsh reachable from pwsh ----
# zsh.exe lives in Git\usr\bin (scripts/install-zsh.sh --system), and only
# Git\cmd is on the Windows PATH by default -- so a pwsh opened straight from
# the WezTerm launch menu cannot find `zsh` at all. A pwsh started *from* zsh
# inherits a usable PATH and works by accident. Appending the directory makes
# shell hopping work from any starting point.
#
# One entry now does two jobs. zsh.exe is an MSYS binary linking against
# msys-2.0.dll, which sits in that same directory, so the loader resolves it
# beside the executable -- no second path needed. Back when zsh was installed
# portably under ~/.local\zsh, that prefix had to be appended as well, and
# omitting Git\usr\bin made zsh resolve but die instantly with 0xC0000135
# (STATUS_DLL_NOT_FOUND) and no message.
#
# APPENDED, never prepended: Git\usr\bin is full of MSYS coreutils (find.exe,
# sort.exe ...) that would shadow the Windows ones and break scripts expecting
# Windows semantics. Appended, the Windows versions win.
$msysBin = "$env:ProgramFiles\Git\usr\bin"
if ((Test-Path $msysBin) -and (($env:PATH -split ';') -inotcontains $msysBin)) {
    $env:PATH = "$env:PATH;$msysBin"
}
Set-Alias lssh lazyssh
function cc { claude --allow-dangerously-skip-permissions @args }

# ---- bash means Git Bash, not WSL ----
# C:\Windows\System32\bash.exe is the WSL launcher, and System32 sits early on
# PATH, so a bare `bash` in pwsh dropped into Ubuntu rather than the Git Bash
# that .bashrc and the WezTerm launch menu are built around.
#
# Done as a function rather than by prepending "C:\Program Files\Git\bin",
# because that directory also holds git.exe -- prepending it would silently
# move `git` off Git\cmd\git.exe, the wrapper Git for Windows intends to be on
# PATH. A function changes `bash` and nothing else. WSL stays reachable as
# `wsl`, or `wsl-bash` to land straight in its shell.
$gitBash = "$env:ProgramFiles\Git\bin\bash.exe"
if (Test-Path $gitBash) {
    function bash { & "$env:ProgramFiles\Git\bin\bash.exe" @args }
}
function wsl-bash { & "$env:SystemRoot\System32\bash.exe" @args }

# ---- eza aliases ----
function ls { eza --icons --group-directories-first --git-repos --color-scale=all @args }
function la { eza --icons --all --group-directories-first --git-repos --color-scale=all @args }
function ll { eza --icons -l --all --git --git-repos --header --group-directories-first --color-scale=all @args }
function lt { eza --icons --tree --level=2 @args }

# ---- zoxide (smart cd) ----
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# Give cd the z behaviour without giving up z. `--cmd cd` would rename z/zi to
# cd/cdi rather than add to them, so point cd at the same functions z uses.
# __zoxide_z only queries the database when its argument is not something cd
# could handle itself, so a real path, `-` or no argument still behave normally.
# AllScope + Force is what zoxide's own --cmd emits; it is needed to displace
# PowerShell's built-in cd alias for Set-Location.
Microsoft.PowerShell.Utility\Set-Alias -Name cd -Value __zoxide_z -Option AllScope -Scope Global -Force
Microsoft.PowerShell.Utility\Set-Alias -Name cdi -Value __zoxide_zi -Option AllScope -Scope Global -Force
