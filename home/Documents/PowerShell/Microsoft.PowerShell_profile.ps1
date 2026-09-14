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
# zsh lives in a portable prefix that nothing else puts on PATH. A pwsh started
# *from* zsh inherits it and `zsh` works by accident; a pwsh opened straight
# from the WezTerm launch menu does not, and `zsh` is simply not found. Append
# it so shell hopping works from any starting point. Appended rather than
# prepended, and nothing else on PATH is named zsh, so this shadows nothing.
#
# Git's usr\bin has to come along too. zsh.exe is an MSYS binary and links
# against msys-2.0.dll, which lives there -- and only Git\cmd is on the Windows
# PATH, not Git\usr\bin. Without it zsh resolves but dies instantly with
# 0xC0000135 (STATUS_DLL_NOT_FOUND) and no message. WezTerm happens to inject
# that directory for its own sessions, so this only bites a pwsh started
# somewhere else; adding it here makes the profile self-sufficient.
#
# Both are APPENDED, never prepended: Git\usr\bin is full of MSYS coreutils
# (find.exe, sort.exe ...) that would shadow the Windows ones and break
# scripts expecting Windows semantics. Appended, the Windows versions win.
$zshBin = "$HOME\.local\zsh\usr\bin"
$msysBin = "$env:ProgramFiles\Git\usr\bin"
foreach ($p in @($msysBin, $zshBin)) {
    if ((Test-Path $p) -and (($env:PATH -split ';') -inotcontains $p)) {
        $env:PATH = "$env:PATH;$p"
    }
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
