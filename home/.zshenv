# ============================================================
# Zsh Environment — WezTerm Setup
# ============================================================
# Managed by dotbot — run ./install from the repo to symlink.
#
# Read for EVERY zsh invocation (scripts included), so keep this minimal.
#
# zsh is installed portably under ~/.local/zsh (scripts/install-zsh.sh), but
# its compiled-in prefix is /usr, which points into the Git for Windows tree.
# Without these overrides zsh finds none of its modules (zle, complete, ...)
# and no completion functions.
# ============================================================

# ${HOME//\\//} guards the globs below: zsh treats a backslash in a glob as an
# escape, which silently breaks it if HOME is ever a Windows-style path.
_zsh_root="${HOME//\\//}/.local/zsh"

if [[ -d $_zsh_root ]]; then
   # Resolve the installed version rather than hardcoding it, so upgrading the
   # package does not require editing this file.
   _zsh_libs=("$_zsh_root/usr/lib/zsh"/*(/N))
   (( $#_zsh_libs )) && module_path=("${_zsh_libs[-1]}")

   # The recursive **/* glob over the functions tree measured at ~72ms, and this
   # file is read by EVERY zsh invocation -- scripts and subshells included, not
   # just interactive shells. Cache the resolved directory list and read it back
   # instead. `$(<file)` is handled internally by zsh, so this costs no fork.
   #
   # The staleness check is the mtime of the top functions directory, which only
   # changes when an entry is added or removed directly beneath it. Adding a
   # function deeper in the tree will not invalidate the cache -- delete
   # $_fpath_cache (or the whole ~/.cache/zsh) after upgrading zsh.
   _zsh_fns="$_zsh_root/usr/share/zsh/functions"
   if [[ -d $_zsh_fns ]]; then
      _zc="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
      _fpath_cache="$_zc/fpath"
      if [[ ! -s $_fpath_cache || $_zsh_fns -nt $_fpath_cache ]]; then
         [[ -d $_zc ]] || mkdir -p $_zc
         print -rl -- "$_zsh_fns"/**/*(/N) "$_zsh_fns" >| $_fpath_cache
      fi
      fpath=("${(@f)"$(<$_fpath_cache)"}" $fpath)
      unset _zc _fpath_cache
   fi

   unset _zsh_libs _zsh_fns
fi
unset _zsh_root
