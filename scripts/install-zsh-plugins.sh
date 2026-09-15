#!/usr/bin/env bash
# ============================================================
# Install the antidote plugin manager for zsh
# ============================================================
# antidote is pure zsh -- no binary, no compiler, no package manager -- so it is
# just a git clone, which matters with no pacman on this machine. It also does
# static bundling: the plugin list flattens into one sourceable file, so startup
# pays no per-plugin cost.
#
# The plugin list lives in home/.zsh_plugins.txt, not here. antidote clones each
# into ~/.cache/antidote on first use; they are third-party repos and are
# deliberately not vendored.
#
# Usage:
#   ./install-zsh-plugins.sh          # install/update antidote, then bundle
#   ./install-zsh-plugins.sh --force  # re-clone antidote from scratch
#
# Idempotent: re-running just fast-forwards antidote and re-bundles.
# ============================================================
set -euo pipefail

ANTIDOTE_DIR="$HOME/.local/antidote"
ANTIDOTE_URL="https://github.com/mattmc3/antidote.git"
ZSH_BIN="/c/Program Files/Git/usr/bin/zsh.exe"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

if [[ $FORCE -eq 1 ]]; then
   rm -rf "$ANTIDOTE_DIR"
fi

if [[ -d "$ANTIDOTE_DIR/.git" ]]; then
   echo "==> updating antidote"
   git -C "$ANTIDOTE_DIR" pull --ff-only --quiet || echo "    (pull failed, keeping existing checkout)"
else
   echo "==> cloning antidote into $ANTIDOTE_DIR"
   mkdir -p "$(dirname "$ANTIDOTE_DIR")"
   git clone --depth 1 --quiet "$ANTIDOTE_URL" "$ANTIDOTE_DIR"
fi

if [[ ! -r "$ANTIDOTE_DIR/antidote.zsh" ]]; then
   echo "error: $ANTIDOTE_DIR/antidote.zsh missing after install" >&2
   exit 1
fi

# Pre-clone the plugins now rather than making the next interactive shell wait
# on a network round-trip. .zshrc regenerates the bundle whenever the plugin
# list is newer than the cached bundle, so this is only a warm-up.
if [[ -x "$ZSH_BIN" && -r "$HOME/.zsh_plugins.txt" ]]; then
   echo "==> cloning plugins from ~/.zsh_plugins.txt"
   # antidote shells out to `zsh` internally, so it must be resolvable from
   # inside the shell it starts. Automatic here: zsh.exe is in /usr/bin, and
   # ~/.zshenv prepends the MSYS directories for any parent that did not.
   "$ZSH_BIN" -c '
      source "$HOME/.local/antidote/antidote.zsh"
      cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
      [[ -d $cache ]] || mkdir -p $cache
      antidote bundle < "$HOME/.zsh_plugins.txt" >| "$cache/plugins.zsh"
   ' || { echo "error: bundling failed" >&2; exit 1; }
   echo "==> bundled into ~/.cache/zsh/plugins.zsh"
else
   echo "note: skipping bundle -- run ./install so dotbot links ~/.zsh_plugins.txt first"
fi

echo "==> done"
