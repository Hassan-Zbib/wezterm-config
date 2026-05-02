# ============================================================
# PowerShell Profile — WezTerm Shell Integration
# ============================================================
# Managed by dotbot — run ./install from the repo to symlink.
# ============================================================

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

# ---- ~/bin on PATH ----
$env:PATH = "$HOME\bin;$env:PATH"
Set-Alias lssh lazyssh
function cc { claude --allow-dangerously-skip-permissions @args }

# ---- eza aliases ----
function ls { eza --icons --group-directories-first --git-repos --color-scale=all @args }
function la { eza --icons --all --group-directories-first --git-repos --color-scale=all @args }
function ll { eza --icons -l --git --git-repos --header --group-directories-first --color-scale=all @args }
function lt { eza --icons --tree --level=2 @args }

# ---- zoxide (smart cd) ----
Invoke-Expression (& { (zoxide init powershell | Out-String) })
