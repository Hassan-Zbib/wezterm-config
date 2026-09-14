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
   # zsh reads '' as end-quote + start-quote, so those inner quotes are
   # consumed while parsing the assignment and the default "C:\Program Files"
   # install path ends up unquoted -- every prompt then fails with
   # "no such file or directory: /c/Program". Re-quote with " before caching.
   # bash is unaffected: its init quotes the path inside a double-quoted eval.
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

   # `starship init zsh` sets RPROMPT as well as PROMPT, so zsh spawns a SECOND
   # starship process on every single prompt to render the right-hand side.
   # ~/.config/starship.toml deliberately has no `right_format`, so that process
   # returns zero bytes -- measured at 31ms median, against a 28ms floor for
   # merely starting the binary. It is pure overhead on roughly a third of the
   # prompt's total cost.
   #
   # bash and powershell are unaffected: neither of their inits passes --right.
   # That asymmetry is also why right_format stays unset rather than being put
   # to use here -- anything in it would be invisible in two of the three shells.
   #
   # If a right-hand prompt is ever wanted in zsh specifically, delete this line
   # and set `right_format` in starship.toml; the process is being paid for
   # either way.
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

# ---- carapace ----
# One binary supplying completions for ~500 commands, so per-tool completion
# files never have to be generated or kept in step with installed versions.
# Covers docker, kubectl, aws, gh, cargo, rustup, just, npm, pnpm, yarn, helm,
# terraform, git, eza, delta, bat, zoxide, lazygit, winget... `uv` is the one
# tool here it does not know about.
#
# Must come after compinit: the init is one big `compdef` call.
#
# The generated init opens by prepending carapace's shim directory to PATH as a
# Windows path with a ';' separator:
#     export PATH="C:/Users/.../carapace/bin;$PATH"
# zsh splits PATH on ':', so that single entry lands as two broken ones -- `C`
# and `/Users/.../carapace/bin;/c/Users/hassa/bin`. That directory is not even
# created by this install, so the line is dropped rather than translated.
if (( $+commands[carapace] )); then
   _cara="$_zc/carapace.zsh"
   if [[ ! -s $_cara || ${commands[carapace]} -nt $_cara ]]; then
      carapace _carapace zsh 2>/dev/null | grep -v '^export PATH=' >| $_cara
   fi
   source $_cara
   unset _cara
fi

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
# SHARE_HISTORY went with it. It synchronised sessions by appending to and
# re-reading HISTFILE, which no longer exists -- and atuin covers that case
# better anyway: every shell reads the same DB live, not just zsh talking to zsh.
#
# EXTENDED_HISTORY went too. It only ever controlled the on-disk timestamp
# format of a file that is no longer written; atuin timestamps natively.
#
# HIST_IGNORE_SPACE stays. atuin honours the leading-space convention itself on
# zsh (the bash-preexec path notably does not), so a space-prefixed command
# stays out of BOTH the in-memory ring and the atuin DB.
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
# Keep zsh's own bin dir on PATH so `zsh` resolves from inside zsh too, matching
# what ~/.bashrc does. Appended so the versioned zsh-5.9.2.exe beside it is
# never picked up by accident.
export PATH="$HOME/bin:$PATH:$HOME/.local/zsh/usr/bin"

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
# Cost note: _atuin_precmd backgrounds its `history end` call, but _atuin_preexec
# must run `history start` synchronously to capture the row id -- measured at
# ~50ms here, against a ~35ms floor for any native-binary fork under MSYS. That
# lands between pressing Enter and the command starting, not on prompt render.
# The daemon that would avoid it is still marked *Experimental* upstream.
#
# This also defines _zsh_autosuggest_strategy_atuin and prepends `atuin` to
# ZSH_AUTOSUGGEST_STRATEGY -- which the autosuggestions block below then
# overwrites, so that block sets the strategy explicitly instead.
(( $+commands[atuin] )) && _cached_init atuin atuin init zsh

# ---- zoxide (smart cd) ----
# Warp manages its own prompt integration and drops zoxide's hook, tripping the
# doctor false-positive. zoxide still works; just silence the diagnostic.
[[ "$TERM_PROGRAM" == "WarpTerminal" ]] && export _ZO_DOCTOR=0
_cached_init zoxide zoxide init zsh

# zoxide 0.10.0 emits a broken __zoxide_pwd on Windows -- the command
# substitution is missing:
#     \command cygpath -w "\builtin pwd -L"
# so cygpath converts that literal text instead of the current directory, and
# the chpwd hook then runs `zoxide add -- "C:\builtin pwd -L"`. Every directory
# change prints "zoxide: not a directory: C:\builtin pwd -L" and nothing is
# ever recorded, so the database silently stops learning.
#
# `zoxide init bash` emits the identical line, so this is not zsh-specific.
# Redefine the function after sourcing, rather than patching the cached text,
# so it keeps working when the cache is regenerated.
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
# Oh My Zsh's plugin of this name needs a distro package database (Debian's
# command-not-found, Arch's pkgfile, Homebrew...). None of those exist on this
# machine, so it would load and silently do nothing. winget is the package
# manager actually in use here, and `winget search` answers in ~300-450ms --
# a cost only paid when a command genuinely was not found.
command_not_found_handler() {
   local cmd=$1
   print -u2 "zsh: command not found: $cmd"
   (( $+commands[winget] )) || return 127

   # winget prints a header and a separator first, so results start at line 3.
   local hits
   hits=$(winget search --query "$cmd" --disable-interactivity 2>/dev/null \
          | tr -d '\r' | sed -n '3,6p')
   if [[ -n $hits ]]; then
      print -u2 ""
      print -u2 "winget has:"
      print -u2 "$hits"
      print -u2 ""
      print -u2 "  install with: winget install --id <Id>"
   fi
   return 127
}

# ============================================================
# Plugins  (antidote — list lives in ~/.zsh_plugins.txt)
# ============================================================
# All of this has to come AFTER the fzf integration above: `fzf --zsh` binds
# Tab (^I), and fzf-tab needs to wrap that existing binding.

# ---- zsh-autosuggestions ----
# overlay0 from Catppuccin Macchiato — the same dim tone the cheatsheet uses.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6e738d'
# Ghost text comes from atuin's DB, not zsh's ring -- the ring now holds only
# the current session (see the History block above), so leaving this on
# `history` would silently shrink suggestions to commands typed since this pane
# opened. `atuin init zsh` defines _zsh_autosuggest_strategy_atuin for exactly
# this. Assigning the variable here rather than letting atuin prepend to it
# keeps one authoritative assignment; atuin's injection runs earlier in the file
# and would be clobbered by this line regardless.
#
# The `$+commands` guard matters: leaving `atuin` in this list without the
# function defined prints "command not found: _zsh_autosuggest_strategy_atuin"
# on every prompt. Falling back to session-only ghost text is the right
# degraded state.
#
# The `completion` strategy is deliberately absent from both branches: in async mode
# (the default) it fetches its suggestion by forking a zpty, writing a literal
# Tab into it, then doing an uncapped blocking read --
#     zpty -r $PTY line '*'$'\0''*'$'\0'
# -- which accumulates everything the child writes into a single variable until
# it sees null-delimited output. That Tab lands in a shell where fzf-tab owns
# ^I, so the child launches an interactive fzf picker that has no user to answer
# it and never emits the terminating null. The read never returns and $line
# grows without bound: measured here at 11.5GB resident / 35.7GB commit before
# the shell deadlocked outright, twice within four minutes.
#
# It only ever fired when history had no match, which is why it looked fine for
# days. Little is lost by dropping it -- it supplied ghost text for commands
# with no history entry, and fzf-tab already covers that discovery on Tab.
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
