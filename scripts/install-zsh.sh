#!/usr/bin/env bash
# ============================================================
# Install MSYS2 zsh into the Git for Windows tree
# ============================================================
# Git for Windows ships no zsh and no pacman, but it IS an MSYS2 runtime and
# already bundles every DLL zsh needs (msys-2.0, msys-ncursesw6, msys-pcre2-8-0,
# msys-iconv-2), so the msys/zsh package can simply be unpacked and run.
#
# The package is unpacked into C:\Program Files\Git, so zsh.exe lands in
# /usr/bin beside msys-2.0.dll and shares Git's MSYS root, mount table and
# /etc. That makes zsh's compiled-in prefix of /usr point at the real thing:
# modules (zle, complete, ...) and completion functions are found with no help,
# and any Win32 parent can spawn zsh.exe directly.
#
# This needs admin, and a Git for Windows upgrade can wipe files added under
# C:\Program Files\Git. Both are accepted deliberately. The script is
# idempotent and ./install runs it, so recovering from an upgrade is a matter
# of running the installer again.
#
# It used to default to a portable install under ~/.local/zsh -- no admin, and
# immune to Git upgrades. That was dropped because zsh's compiled-in /usr then
# points into a tree zsh is not installed in, and everything downstream has to
# compensate: ~/.zshenv had to redirect module_path and splice a cached,
# recursively-globbed functions tree onto fpath; nothing under /etc was ever
# read; and any Win32 process that spawned zsh.exe without first putting Git's
# usr/bin on PATH got exit code 0xC0000135 (STATUS_DLL_NOT_FOUND) with no
# message -- which is exactly how it failed under herdr. See git history for
# the portable code path if it is ever needed again.
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

# The package ships /etc/zsh/zprofile containing nothing but
#     emulate sh -c 'source /etc/profile'
# and zsh reads the GLOBAL zprofile before ~/.zprofile. home/.zprofile already
# does that job from a cache -- /etc/profile measured at ~101ms, the single
# largest item in startup -- so leaving this file in place would pay the full
# cost on every login shell and then consult the cache for nothing. Removing it
# is safe: ~/.zprofile sources /etc/profile directly whenever its cache is
# missing, stale or bad.
#
# Done after extraction rather than with --exclude so that a --force reinstall
# over an existing tree removes it too.
rm -f "$DEST/etc/zsh/zprofile"

echo "==> installed: $("$ZSH_EXE" --version)"
echo "==> WezTerm path: $(cygpath -w "$ZSH_EXE")"

if [[ ! -e "$HOME/.zshenv" ]]; then
   echo
   echo "note: ~/.zshenv is missing -- run ./install from the repo root so"
   echo "      dotbot links the shell dotfiles."
fi
