# ============================================================
# Zsh Configuration — WezTerm Setup
# ============================================================
# Managed by dotbot — run ./install from the repo to symlink.
# Mirrors ~/.bashrc; bash stays installed and Claude Code still uses it.
# ============================================================

# ---- Init cache ----
# Every `eval "$(tool init zsh)"` forks a process, and a fork on the MSYS2
# runtime costs ~30ms before the tool even runs (starship alone is ~130ms).
# Cache each tool's output and re-source it, regenerating only when the binary
# is newer than the cache.
_zc="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d $_zc ]] || mkdir -p $_zc

_cached_init() {
   local name=$1 cache
   shift
   cache="$_zc/$name.zsh"
   if [[ ! -s $cache || ${commands[$1]} -nt $cache ]]; then
      "$@" >| $cache 2>/dev/null
   fi
   source $cache
}

# ---- SHELL ----
# The MSYS runtime sets SHELL from /etc/passwd (bash), and .zprofile's cached
# /etc/profile environment carries that over, so tools that open "your shell"
# (lazygit, vim's :sh, fzf previews outside fzf-tab) started bash. The POSIX
# path is fine for native programs: MSYS rewrites SHELL to the Windows path
# when it spawns them. Set here rather than .zshenv so scripts are unaffected.
[[ -x /usr/bin/zsh ]] && export SHELL=/usr/bin/zsh

# ---- WezTerm Shell Integration ----
# OSC 7: Tracks current directory so WezTerm tab title updates automatically.
# This runs on every prompt, so the percent-encoding is done with parameter
# expansion rather than a loop: (#m) captures each character that is not
# URL-safe, and $MATCH is converted to two uppercase hex digits.
__wezterm_set_cwd() {
   setopt localoptions extendedglob
   local enc=${PWD//(#m)[^a-zA-Z0-9.~_\/-]/%${(l:2::0:)$(([##16]#MATCH))}}
   printf '\033]7;file://localhost%s\033\\' "$enc"
}

# ---- Skip heavy init when running inside Claude Code ----
if [[ -z "$CLAUDECODE" ]]; then
   # ---- WezTerm Shell Integration ----
   # Skip under Warp: it runs its own prompt/Blocks integration, and the OSC
   # 7 / OSC 133 markers corrupt Warp's command Blocks.
   if [[ "$TERM_PROGRAM" != "WarpTerminal" ]]; then
      # OSC 133: Mark prompt boundaries for ScrollToPrompt (Shift+Up/Down).
      # zsh has real hooks, so unlike bash this needs no PROMPT_COMMAND
      # string-append and no DEBUG trap (which fired once per pipeline stage).
      autoload -Uz add-zsh-hook

      __wezterm_precmd() {
         local ret=$?
         printf '\033]133;D;%s\033\\' "$ret"   # command finished
         __wezterm_set_cwd                      # OSC 7
         printf '\033]133;A\033\\'              # prompt start
      }

      __wezterm_preexec() {
         printf '\033]133;C\033\\'              # output start
      }

      # Registered before starship so $? is still the real exit status.
      add-zsh-hook precmd __wezterm_precmd
      add-zsh-hook preexec __wezterm_preexec
   fi

   # ---- Starship Prompt ----
   # `starship init zsh` wraps its own path in '' inside an already
   # single-quoted PROMPT:
   #     PROMPT='$(''/c/Program Files/.../starship.exe'' prompt ...)'
   # zsh reads '' as end-quote + start-quote, leaving the "C:\Program Files"
   # path unquoted, so every prompt fails with "no such file or directory:
   # /c/Program". Re-quote with " before caching. bash is unaffected.
   _starship_cache="$_zc/starship.zsh"
   if [[ ! -s $_starship_cache || ${commands[starship]} -nt $_starship_cache ]]; then
      _starship_init="$(starship init zsh)"
      _starship_init=${_starship_init//\$\(\'\'/\$\(\"}
      _starship_init=${_starship_init//\'\' prompt/\" prompt}
      print -r -- "$_starship_init" >| $_starship_cache
      unset _starship_init
   fi
   source $_starship_cache
   unset _starship_cache

   # `starship init zsh` also sets RPROMPT, so zsh spawns a SECOND starship
   # process per prompt. starship.toml has no `right_format`, so it returns zero
   # bytes for 31ms median -- about a third of the prompt's cost, for nothing.
   # bash and powershell do not pass --right, which is also why `right_format`
   # stays unset: anything there would be invisible in two of three shells.
   unset RPROMPT
fi

# ---- Completion ----
# compaudit (the insecure-directory scan) is the slow half of compinit. Run the
# full check at most once a day; otherwise -C trusts the existing dump.
autoload -Uz compinit
if [[ ! -s $_zc/zcompdump || -n $_zc/zcompdump(#qN.mh+24) ]]; then
   compinit -d "$_zc/zcompdump"
else
   compinit -C -d "$_zc/zcompdump"
fi

# Fall back to plain filename completion when the command's own completer came
# up empty. zsh only runs the second completer when the first matched nothing,
# so commands with real candidates are untouched. This covers carapace's
# `[[ ${#valuesArr[@]} -gt 1 ]]` guard, which silently drops any group holding
# exactly one candidate -- without the fallback, `glow R<Tab>` offers nothing
# even though README.md is the only match.
#
# Only effective together with the _carapace_completer wrapper below: carapace's
# function ends in a `while` loop, so it reports success even when it added no
# matches, and zsh would stop before reaching _files.
zstyle ':completion:*' completer _complete _files

# ---- carapace ----
# One binary supplying completions for ~500 commands (docker, kubectl, gh,
# cargo, git, eza, winget...), so per-tool completion files never need
# generating. `uv` is the one tool here it does not know.
#
# Must come after compinit: the init is one big `compdef` call.
#
# Its first line prepends carapace's shim dir as a Windows path with a ';'
# separator, which zsh splits on ':' into two broken PATH entries. That dir is
# never created by this install, so the line is dropped rather than translated.
#
# The sed is what makes carapace work at all on Windows. Its completer exports
# the shell's state to the binary, and CARAPACE_SHELL_FUNCTIONS is
# `print -l ${(ok)functions}` -- evaluated *during* completion, so it lists every
# _* function compinit has autoloaded: ~28KB on its own. CreateProcess caps the
# whole environment block at 32767 chars, so the exec failed with
#     xargs: environment is too large for exec
# and every carapace-owned command (git, glow, bat, eza...) silently completed
# to nothing. The variable only feeds specs that complete shell function names,
# none of which are used here, so it is blanked. The other CARAPACE_SHELL_*
# exports are a few KB together and stay.
if (( $+commands[carapace] )); then
   _cara="$_zc/carapace.zsh"
   if [[ ! -s $_cara || ${commands[carapace]} -nt $_cara ]]; then
      carapace _carapace zsh 2>/dev/null \
         | grep -v '^export PATH=' \
         | sed 's/^\([[:space:]]*declare -x CARAPACE_SHELL_FUNCTIONS=\).*/\1""/' >| $_cara
   fi
   source $_cara
   unset _cara

   # carapace's completer ends in a `while` loop over its result blocks, so it
   # returns 0 whether or not it added anything -- and zsh's completer chain
   # stops at the first success, so the _files fallback set above could never
   # run. Wrap it to report the truth. Idempotent: re-sourcing this file
   # re-sources the cache first, which restores the original function.
   functions[_carapace_unwrapped]=$functions[_carapace_completer]
   _carapace_completer() {
      local -i _nm=$compstate[nmatches]
      _carapace_unwrapped "$@"
      (( compstate[nmatches] > _nm ))
   }
fi

# ---- herdr ----
# carapace has no spec for herdr, so Tab fell back to filenames. herdr ships
# its own clap-generated completion; like the carapace init it ends in a
# `compdef`, so it must come after compinit.
(( $+commands[herdr] )) && _cached_init herdr herdr completion zsh

# ---- Key bindings ----
# zsh uses ZLE, not GNU Readline, so it reads neither ~/.inputrc nor Git's
# /etc/inputrc. Everything bash got from those two files plus readline's
# defaults has to be re-declared here. Keep this in sync with the
# "Line editing" block in scripts/cheatsheet.py.
bindkey -e                                    # emacs keymap, as in bash

# Word motions the readline way (alphanumeric words). Without this zsh's
# WORDCHARS swallows punctuation, so Ctrl+Left would jump over a whole path.
autoload -Uz select-word-style
select-word-style bash

# -- Movement --
bindkey '\eOH'    beginning-of-line           # Alt+Left  (bindings.lua sends Home)
bindkey '\eOF'    end-of-line                 # Alt+Right (bindings.lua sends End)
bindkey '\e[H'    beginning-of-line           # Home
bindkey '\e[F'    end-of-line                 # End
bindkey '\e[1~'   beginning-of-line           # Home (alternate encoding)
bindkey '\e[4~'   end-of-line                 # End  (alternate encoding)
bindkey '\e[1;5D' backward-word               # Ctrl+Left
bindkey '\e[1;5C' forward-word                # Ctrl+Right

# -- Deletion --
# Deletion scope, narrowest to widest:
#   Ctrl+Backspace / Alt+Backspace  alphanumeric word
#   Ctrl+w                          back to whitespace
#   Ctrl+u                          back to line start
bindkey '\e[3~'   delete-char                 # Delete
bindkey '^H'      backward-kill-word          # Ctrl+Backspace (WezTerm sends C-h)
bindkey '\e[3;5~' kill-word                   # Ctrl+Delete
bindkey '\e[3;3~' kill-word                   # Alt+Delete
# zsh's ^U is kill-whole-line; bash's is unix-line-discard. Ctrl+Shift+Bksp in
# bindings.lua sends ^E^U and relies on this deleting backwards only.
bindkey '^U'      backward-kill-line          # Ctrl+u

# Ctrl+w deletes back to whitespace, a wider scope than the bash word style set
# above. select-word-style drives the *-match widgets through zstyle, so give
# this one widget its own word-style rather than fighting WORDCHARS.
zle -N __backward-kill-whitespace-word backward-kill-word-match
zstyle ':zle:__backward-kill-whitespace-word' word-style whitespace
bindkey '^W'      __backward-kill-whitespace-word

# Shift+Enter inserts a newline without submitting. bindings.lua sends this as
# a bracketed paste, which zsh handles natively; this covers the kitty
# keyboard protocol encoding as well.
__insert_newline() { LBUFFER+=$'\n' }
zle -N __insert_newline
bindkey '\e[13;2u' __insert_newline

# ---- History ----
# atuin owns persistent history: one SQLite DB shared by every shell, searched
# with Ctrl+R (everything) and Up (this directory). zsh keeps an IN-MEMORY ring
# only -- HISTSIZE is what feeds !! / !$ expansion and ZLE within this session.
#
# SAVEHIST=0 with no HISTFILE means ~/.zsh_history is never read or written, so
# atuin is the single persistent store rather than a second copy of one. The old
# file is left on disk; it was imported once (`atuin import zsh`, alongside
# `atuin import bash`), after which it is inert and safe to delete.
#
# SHARE_HISTORY and EXTENDED_HISTORY went with it: both only acted on a HISTFILE
# that is no longer written, and atuin covers sharing better -- every shell reads
# the same DB live.
#
# HIST_IGNORE_SPACE stays. atuin honours the leading-space convention itself on
# zsh (the bash-preexec path does not), so a space-prefixed command stays out of
# BOTH the in-memory ring and the atuin DB.
HISTSIZE=10000
SAVEHIST=0
unset HISTFILE
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# An unmatched glob is an error in zsh, where bash passes the pattern through.
setopt NO_NOMATCH

# ---- Yazi File Manager with Auto-cd ----
# Use 'yy' instead of 'yazi' to auto-cd when you quit
yy() {
    local tmp
    tmp="$(mktemp)"
    yazi "$@" --cwd-file="$tmp"
    # WezTerm on Windows doesn't repaint the primary screen after a TUI app
    # leaves the alternate screen, so yazi's frame stays painted on exit.
    # Clear the screen + restore the cursor to redraw a clean prompt.
    [[ "$TERM_PROGRAM" == "WezTerm" ]] && printf '\033[2J\033[H\033[?25h'
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# ---- Claude Code Profile Switcher ----
# Runs the PowerShell switcher from zsh; args pass through to its params.
# e.g. ccp -List | ccp -Status | ccp -Profile MBV_Solutions | ccp (interactive)
ccp() {
    powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File 'C:\Users\hassa\Desktop\GitHub\Claude-Switch\switch.ps1' "$@"
}

# ---- PATH ----
# zsh's own bin dir used to be appended here: a portable install under
# ~/.local/zsh was on no standard path, so `zsh` did not resolve from inside
# zsh. The --system install puts zsh.exe in /usr/bin, which /etc/profile
# already puts on PATH, so only ~/bin needs adding.
export PATH="$HOME/bin:$PATH"

# ---- Aliases ----
alias lg='lazygit'
alias lssh='lazyssh'
alias pkgs='"/c/Users/hassa/AppData/Local/Programs/UniGetUI/UniGetUI.exe" &'
alias ls='eza --icons --group-directories-first --git-repos --color-scale=all'
alias la='eza --icons --all --group-directories-first --git-repos --color-scale=all'
alias ll='eza --icons -l --all --git --git-repos --header --group-directories-first --color-scale=all'
alias lt='eza --icons --tree --level=2'
alias cls='clear'
alias cc='claude --allow-dangerously-skip-permissions'
alias cca='claude agents --allow-dangerously-skip-permissions'
alias ff='fastfetch'
alias bt='btop'

# ---- fzf ----
# Ctrl+t file picker, Alt+c cd picker, plus completion. This also binds Ctrl+r
# to fzf-history-widget, which the atuin block below deliberately overrides --
# see there for why the order of these two matters.
(( $+commands[fzf] )) && _cached_init fzf fzf --zsh

# ---- atuin (shell history) ----
# Owns Ctrl+R (searches everything) and Up (scoped to the current directory via
# filter_mode_shell_up_key_binding in ~/.config/atuin/config.toml -- atuin uses
# the XDG path on Windows too, not %APPDATA%).
#
# MUST come after the fzf block above. `fzf --zsh` binds ^R to
# fzf-history-widget and whichever init runs last wins the key. fzf keeps Ctrl+T
# and Alt+C; only its history widget is superseded, and the now-unbound widget
# function is the only residue.
#
# Safe to cache: `atuin init zsh` output is byte-identical between runs (checked
# with diff), and the session id is a literal `$(atuin uuid)` in that output,
# evaluated when the cache is sourced rather than baked in at generation time.
#
# Cost: _atuin_preexec must run `history start` synchronously to capture the row
# id -- ~50ms, against a ~35ms floor for any native fork under MSYS. It lands
# between Enter and the command starting, not on prompt render. The daemon that
# would avoid it is still Experimental upstream.
#
# This also prepends `atuin` to ZSH_AUTOSUGGEST_STRATEGY, which the
# autosuggestions block below overwrites explicitly.
(( $+commands[atuin] )) && _cached_init atuin atuin init zsh

# ---- zoxide (smart cd) ----
# Warp manages its own prompt integration and drops zoxide's hook, tripping the
# doctor false-positive. zoxide still works; just silence the diagnostic.
[[ "$TERM_PROGRAM" == "WarpTerminal" ]] && export _ZO_DOCTOR=0
_cached_init zoxide zoxide init zsh

# Give cd the z behaviour without giving up z. `--cmd cd` would *rename* z/zi to
# cd/cdi rather than add to them, so delegate instead. __zoxide_z only queries
# the database when its argument is not something cd could handle itself -- no
# argument, `-`, `+N`/`-N` and any real path all still change directory the
# ordinary way -- which is what makes it safe to sit on top of cd.
#
# Completion is deliberately left alone: zoxide compdefs only `z`, so `cd` keeps
# zsh's native _cd and completes directories rather than database entries.
cd()  { __zoxide_z "$@" }
cdi() { __zoxide_zi "$@" }

# zoxide 0.10.0 emits a broken __zoxide_pwd on Windows -- the command
# substitution is missing:
#     \command cygpath -w "\builtin pwd -L"
# so every cd prints "zoxide: not a directory: C:\builtin pwd -L" and the DB
# silently stops learning. `zoxide init bash` is identical, so not zsh-specific.
# Redefined after sourcing rather than patching the cache, so it survives
# regeneration.
__zoxide_pwd() {
   \command cygpath -w "$(\builtin pwd -L)"
}

# ---- bat (cat with syntax highlighting) ----
# Catppuccin Macchiato ships inside bat 0.26, so the theme needs no extra files.
# No MANPAGER setup: Git for Windows ships neither `man` nor `col`, so the usual
# `col -bx | bat -l man` recipe would be dead configuration here.
if (( $+commands[bat] )); then
   export BAT_THEME='Catppuccin Macchiato'
   alias cat='bat --paging=never'
   alias catp='bat --paging=never --style=plain'   # no line numbers or gutter
fi

# ---- command-not-found ----
# REMOVED: a command_not_found_handler that ran `winget search` on every miss.
#
# The earlier "~300-450ms" note measured the search but not what dominates it.
# winget.exe is an MSIX app reached through the App Execution Alias in
# WindowsApps, and that activation is the whole cost: `winget --version`, which
# does no work at all, is ~190ms warm. The query itself is ~30ms, and the
# `tr | sed` pipeline behind it adds two more MSYS forks. Warm total was
# ~220-240ms; cold -- the usual case, since a miss happens far less often than
# Windows keeps the package warm -- it ran into seconds.
#
# No winget flag reaches that floor: --source winget measured the same as the
# default, so there is nothing to tune. Reading winget's own SQLite index
# (LocalState/.../Microsoft.Winget.Source_*/index.db, which has a commands2
# table mapping executables to packages) answers in under 1ms, but needs a
# Python process to do it (~80-140ms) and the local index lags the real catalog
# badly -- it still listed opencode 1.14.x four months after the fact.
#
# All of that was spent on the typo path. Nearly every miss is `gti` or `claer`,
# not a package worth installing, so the lookup taxed the common case to serve
# the rare one. zsh's builtin message covers the common case for free; when a
# package really is wanted, `winget search <name>` is right there to type.

# ============================================================
# Plugins  (antidote — list lives in ~/.zsh_plugins.txt)
# ============================================================
# All of this has to come AFTER the fzf integration above: `fzf --zsh` binds
# Tab (^I), and fzf-tab needs to wrap that existing binding.

# ---- zsh-autosuggestions ----
# overlay0 from Catppuccin Macchiato — the same dim tone the cheatsheet uses.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6e738d'
# Ghost text comes from atuin's DB, not zsh's ring -- the ring holds only this
# session (see History above), so `history` would shrink suggestions to commands
# typed since this pane opened. The `$+commands` guard matters: listing `atuin`
# without its strategy function defined prints "command not found:
# _zsh_autosuggest_strategy_atuin" on every prompt.
#
# The `completion` strategy is deliberately absent. In async mode it forks a
# zpty, writes a literal Tab, then does an uncapped blocking read:
#     zpty -r $PTY line '*'$'\0''*'$'\0'
# That Tab lands in a shell where fzf-tab owns ^I, so the child opens an
# interactive picker nobody can answer and never emits the terminating null.
# $line then grows without bound -- 11.5GB resident before the shell deadlocked,
# twice in four minutes. It only fired when history had no match, and fzf-tab
# already covers that discovery on Tab.
if (( $+commands[atuin] )); then
   ZSH_AUTOSUGGEST_STRATEGY=(atuin)
else
   ZSH_AUTOSUGGEST_STRATEGY=(history)
fi
# Stop suggesting on very long lines; not worth the work per keystroke.
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ---- zsh-syntax-highlighting ----
# `main` covers the common cases and `brackets` matches pairs. The remaining
# highlighters (pattern, cursor, regexp) cost more per keystroke than they give.
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
# Highlighting re-runs on every keystroke, so cap it for long lines.
ZSH_HIGHLIGHT_MAXLENGTH=512

# ---- fzf-tab ----
# fzf-tab needs zsh's own menu off so it can capture the completion list.
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' switch-group ',' '.'
# fzf-tab launches fzf with SHELL=$ZSH_NAME, i.e. the bare word `zsh`. The
# native Windows fzf resolves that against the cwd, not PATH, so every preview
# failed with `exec: "<cwd>\zsh": executable file not found`. --with-shell
# overrides it, but fzf splits the value on whitespace without honouring
# quotes, so "C:/Program Files/..." breaks too -- hence the 8.3 short path.
# zstyle -e defers the cygpath fork to the first Tab instead of every startup.
if [[ $OSTYPE == (msys|cygwin)* ]]; then
   zstyle -e ':fzf-tab:*' fzf-flags '
      (( ${+_ftb_zsh} )) || _ftb_zsh=$(\command cygpath -m -s $commands[zsh] 2>/dev/null)
      if [[ -n $_ftb_zsh && $_ftb_zsh != *" "* ]]; then
         reply=(--with-shell "$_ftb_zsh -c")
      else
         reply=()
      fi'
fi
# Directories preview through eza, files through bat.
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons --color=always -1 -- $realpath'
zstyle ':fzf-tab:complete:z:*'  fzf-preview 'eza --icons --color=always -1 -- $realpath'
zstyle ':fzf-tab:complete:*:*'  fzf-preview '[[ -d $realpath ]] && eza --icons --color=always -1 -- $realpath || bat --color=always --style=plain --line-range=:200 -- $realpath 2>/dev/null'

# ---- Load ----
# Static bundling: antidote flattens the plugin list into a single sourceable
# file, and only that file is read on a normal startup. antidote itself is
# loaded just to regenerate the bundle when the plugin list changes.
_antidote="$HOME/.local/antidote/antidote.zsh"
if [[ -r $_antidote ]]; then
   _plugins_txt="$HOME/.zsh_plugins.txt"
   _plugins_zsh="$_zc/plugins.zsh"
   if [[ ! -s $_plugins_zsh || $_plugins_txt -nt $_plugins_zsh ]]; then
      source $_antidote
      antidote bundle < $_plugins_txt >| $_plugins_zsh
   fi
   source $_plugins_zsh
   unset _plugins_txt _plugins_zsh
fi
unset _antidote

# ---- Post-load ----
# ZSH_HIGHLIGHT_STYLES only exists once the plugin has been sourced.
if (( ${+ZSH_HIGHLIGHT_STYLES} )); then
   ZSH_HIGHLIGHT_STYLES[comment]='fg=#6e738d'         # overlay0, not near-black
   ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ed8796'   # Macchiato red
fi
