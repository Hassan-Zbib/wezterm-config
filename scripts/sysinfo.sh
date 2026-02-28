#!/usr/bin/env bash
# System info panel — displayed once at shell startup
# Catppuccin Macchiato

BLU='\e[38;2;138;173;244m'
GRN='\e[38;2;166;218;149m'
YLW='\e[38;2;238;212;159m'
PRP='\e[38;2;198;160;246m'
SAP='\e[38;2;125;196;228m'
PCH='\e[38;2;245;169;127m'
TEL='\e[38;2;139;213;202m'
DIM='\e[38;2;110;115;141m'
TXT='\e[38;2;202;211;245m'
BLD='\e[1m'
RST='\e[0m'

# ── Static info ───────────────────────────────────────
user_val="${USERNAME:-$(whoami)}@${COMPUTERNAME:-$(hostname)}"
term_val="${TERM_PROGRAM:-WezTerm}"
shell_val="bash ${BASH_VERSION%%(*}"

# ── Dynamic info — single PowerShell call ─────────────
sysdata=$(powershell.exe -NoProfile -NonInteractive -Command '
  $os  = gcim Win32_OperatingSystem
  $cpu = (gcim CIM_Processor).LoadPercentage
  $net = Get-NetIPAddress -AddressFamily IPv4 |
         Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.IPAddress -notmatch "^169" } |
         Select-Object -First 1
  $u   = [DateTime]::Now - $os.LastBootUpTime
  $ud  = if ($u.Days) { "$($u.Days)d, $($u.Hours)h $($u.Minutes)m" } else { "$($u.Hours)h, $($u.Minutes)m" }
  $tm  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
  $um  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
  $st  = [math]::Round($os.SizeStoredInPagingFiles / 1MB, 1)
  $su  = [math]::Round($st - [math]::Round($os.FreeSpaceInPagingFiles / 1MB, 1), 1)
  $ni  = if ($net) { "$($net.IPAddress)/$($net.PrefixLength)" } else { "N/A" }
  Write-Output "$ud|$cpu%|${um}G / ${tm}G|${su}G / ${st}G|$ni"
' 2>/dev/null | tr -d '\r')

IFS='|' read -r uptime_val cpu_val mem_val swap_val net_val <<< "$sysdata"
uptime_val="${uptime_val:-unknown}"
cpu_val="${cpu_val:-unknown}"
mem_val="${mem_val:-unknown}"
swap_val="${swap_val:-unknown}"
net_val="${net_val:-unknown}"

# ── AWS (only if credentials configured) ──────────────
aws_val=""
_ap="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-}}"
_ar="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
[[ -n "$_ap" || -n "$_ar" ]] && aws_val="${_ap}${_ar:+ [$_ar]}"

# ── Display ───────────────────────────────────────────
SEP="$(printf '%.0s─' {1..38})"
lbl() { printf "  ${DIM}|${RST}  ${BLD}${1}%-10s${RST}  ${TXT}%s${RST}\n" "$2" "$3"; }

echo
printf "  ${DIM}+${SEP}${RST}\n"
lbl "$BLU"  "user"      "$user_val"
lbl "$YLW"  "uptime"    "$uptime_val"
lbl "$SAP"  "term"      "$term_val"
lbl "$PRP"  "shell"     "$shell_val"
lbl "$GRN"  "cpu"       "$cpu_val"
lbl "$TEL"  "memory"    "$mem_val"
lbl "$DIM"  "swap"      "$swap_val"
lbl "$BLU"  "network"   "$net_val"
[[ -n "$aws_val" ]] && lbl "$PCH" "aws" "$aws_val"
printf "  ${DIM}+${SEP}${RST}\n"
echo
