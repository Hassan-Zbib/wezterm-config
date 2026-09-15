#!/usr/bin/env bash
# ============================================================
# Install MSYS2 zsh into the Git for Windows tree
# ============================================================
# Git for Windows ships no zsh and no pacman, but it IS an MSYS2 runtime and
# already bundles every DLL zsh needs (msys-2.0, msys-ncursesw6, msys-pcre2-8-0,
# msys-iconv-2), so the msys/zsh package can simply be unpacked and run.
#
# Unpacking into C:\Program Files\Git puts zsh.exe in /usr/bin beside
# msys-2.0.dll, sharing Git's MSYS root, mount table and /etc. zsh's compiled-in
# /usr prefix then points at the real thing: modules and completion functions
# are found with no help, and any Win32 parent can spawn zsh.exe directly.
#
# The costs are accepted deliberately: it needs admin, and a Git for Windows
# upgrade can wipe it. The script is idempotent and ./install runs it, so
# recovery is just running the installer again.
#
# A portable install under ~/.local/zsh avoided both, but left the compiled-in
# /usr pointing into a tree zsh was not in: ~/.zshenv had to redirect
# module_path and fpath, nothing under /etc was read, and any Win32 parent that
# spawned zsh.exe without Git's usr/bin on PATH got 0xC0000135
# (STATUS_DLL_NOT_FOUND) with no message -- exactly how it failed under herdr.
# See git history if that path is ever needed again.
#
# Usage:
#   ./install-zsh.sh           # install into C:\Program Files\Git (needs admin)
#   ./install-zsh.sh --force   # reinstall even if already present
#
# Idempotent: exits early when the target version is already installed, so
# dotbot can run it on every ./install.
# ============================================================
set -euo pipefail

ZSH_VER="5.9.2"
PKG="zsh-${ZSH_VER}-1-x86_64.pkg.tar.zst"
URL="https://mirror.msys2.org/msys/x86_64/${PKG}"

# Windows' bundled bsdtar understands .zst; Git's GNU tar shells out to a zstd
# binary that Git for Windows does not ship.
TAR="/c/Windows/System32/tar.exe"

FORCE=0
for arg in "$@"; do
   case "$arg" in
      --force) FORCE=1 ;;
      *) echo "error: unknown argument '$arg'" >&2; exit 2 ;;
   esac
done

DEST="/c/Program Files/Git"
ZSH_EXE="$DEST/usr/bin/zsh.exe"

# ---- already installed? ----
if [[ $FORCE -eq 0 && -x "$ZSH_EXE" ]]; then
   if "$ZSH_EXE" --version 2>/dev/null | grep -q "zsh $ZSH_VER"; then
      echo "zsh $ZSH_VER already installed at $ZSH_EXE"
      exit 0
   fi
fi

if ! touch "$DEST/.zsh-write-test" 2>/dev/null; then
   echo "error: cannot write to $DEST -- run this from an elevated shell." >&2
   exit 1
fi
rm -f "$DEST/.zsh-write-test"

mkdir -p "$DEST"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> downloading $PKG"
curl -fsSL -o "$tmp/$PKG" "$URL"

echo "==> unpacking into $DEST"
"$TAR" -xf "$tmp/$PKG" -C "$DEST" \
   --exclude .BUILDINFO --exclude .INSTALL --exclude .MTREE --exclude .PKGINFO

# The package ships /etc/zsh/zprofile containing only
#     emulate sh -c 'source /etc/profile'
# and zsh reads the GLOBAL zprofile before ~/.zprofile, which already does that
# job from a cache. Leaving it would pay the full ~101ms on every login shell and
# then consult the cache for nothing. Safe to remove: ~/.zprofile sources
# /etc/profile directly whenever its cache is missing or stale.
#
# After extraction rather than via --exclude, so a --force reinstall drops it too.
rm -f "$DEST/etc/zsh/zprofile"

echo "==> installed: $("$ZSH_EXE" --version)"
echo "==> WezTerm path: $(cygpath -w "$ZSH_EXE")"

if [[ ! -e "$HOME/.zshenv" ]]; then
   echo
   echo "note: ~/.zshenv is missing -- run ./install from the repo root so"
   echo "      dotbot links the shell dotfiles."
fi
