# ============================================================
# Zsh Login Profile — WezTerm Setup
# ============================================================
# Managed by dotbot — run ./install from the repo to symlink.
#
# Git for Windows' /etc/profile sets up PATH, MSYSTEM and the MSYS mount table.
# It has a ZSH_VERSION branch so it is safe to source from zsh; `emulate sh` is
# needed because the file is POSIX sh.
#
# This REPLACES the /etc/zsh/zprofile the MSYS2 zsh package ships (a single
# uncached source of the same file). zsh reads the global zprofile first, so
# leaving it installed would pay the full ~101ms on every login shell and then
# consult this cache for nothing. scripts/install-zsh.sh deletes it.
# ============================================================
# ---- Cached ----
# /etc/profile costs ~101ms, the largest single item in startup, with no hot spot
# to fix: ~6 forks at 13-25ms each on the MSYS2 runtime. Its entire observable
# effect is a set of exported variables, so cache those and skip the forks.
#
# PATH is the cache key, since everything /etc/profile derives comes from it --
# launch zsh with a different PATH and the cache regenerates rather than applying
# the wrong environment. The cache is also dropped when /etc/profile or
# /etc/profile.d is touched, which is what a Git for Windows upgrade does.
#
# An allowlist, not a blanket dump: dumping every exported variable would bake
# per-session values (WEZTERM_PANE, SSH_AUTH_SOCK...) into the cache and
# re-export stale copies into later shells. Aliases are not cached either --
# profile.d defines only `ls`/`ll`, which ~/.zshrc replaces with eza.
_zc="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
_pc="$_zc/profile-env.zsh"
_pkey="$PATH"

_pc_ok=0
if [[ -s $_pc && ! /etc/profile -nt $_pc && ! /etc/profile.d -nt $_pc ]]; then
   read -r _pc_line < $_pc            # builtin read, no fork
   [[ $_pc_line == "# key: $_pkey" ]] && _pc_ok=1
fi

if (( _pc_ok )); then
   source $_pc
else
   emulate sh -c 'source /etc/profile'

   [[ -d $_zc ]] || mkdir -p $_zc
   zmodload -F zsh/parameter p:parameters
   {
      print -r -- "# key: $_pkey"
      for _pc_v in ACLOCAL_PATH CONFIG_SITE DISPLAY HOSTNAME INFOPATH LANG \
                   MANPATH MINGW_CHOST MINGW_PACKAGE_PREFIX MINGW_PREFIX \
                   MSYSTEM MSYSTEM_CHOST MSYSTEM_PREFIX ORIGINAL_PATH \
                   ORIGINAL_TEMP ORIGINAL_TMP PATH PKG_CONFIG_PATH \
                   PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH \
                   PS1 SHELL SSH_ASKPASS TEMP TMP USER; do
         # /etc/profile's final `export` line names USER without ever assigning
         # it, leaving a "scalar-export" parameter: exported, but with no value.
         # That is not in $parameters, so the type check is what catches it.
         #
         # It comes back as USER='' rather than valueless -- zsh cannot recreate
         # "exported but unset" from a sourced assignment; both `export USER` and
         # `typeset -gx USER` produce an empty string. This is the one byte where
         # the cached environment differs from the real one, and it is
         # indistinguishable in use: $USER expands to empty either way, and Git
         # for Windows never assigns it in the first place.
         if (( ${+parameters[$_pc_v]} )); then
            print -r -- "export $_pc_v=${(qq)${(P)_pc_v}}"
         elif [[ ${(Pt)_pc_v} == *export* ]]; then
            print -r -- "export $_pc_v"
         fi
      done
   } >| $_pc
   unset _pc_v
fi

# Safety net: if a cache ever goes bad, the MSYS bin directory is the first
# thing to disappear from PATH and nothing else in the shell would work. Fall
# back to the real thing and drop the cache so the next start regenerates it.
if [[ ! -d /usr/bin || -z $MSYSTEM ]]; then
   rm -f $_pc
   emulate sh -c 'source /etc/profile'
fi

unset _zc _pc _pkey _pc_ok _pc_line
