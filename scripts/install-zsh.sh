#!/usr/bin/env bash
# ============================================================
# Install MSYS2 zsh alongside the Git for Windows bash
# ============================================================
# Git for Windows ships no zsh and no pacman, but it IS an MSYS2 runtime and
# already bundles every DLL zsh needs (msys-2.0, msys-ncursesw6, msys-pcre2-8-0,
# msys-iconv-2), so the msys/zsh package can simply be unpacked and run.
#
# Default is a portable install into ~/.local/zsh: no admin rights, and it
# survives Git for Windows updates (which can wipe added files under
# C:\Program Files\Git). Because zsh's compiled-in prefix is /usr -- which
# points into the Git tree -- a portable install has to redirect module_path
# and fpath itself; ~/.zshenv does that (linked from home/.zshenv by dotbot).
#
# Usage:
#   ./install-zsh.sh             # portable install into ~/.local/zsh
#   ./install-zsh.sh --system    # into C:\Program Files\Git (needs admin)
#   ./install-zsh.sh --force     # reinstall even if already present
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

MODE="portable"
FORCE=0
for arg in "$@"; do
   case "$arg" in
      --system)   MODE="system" ;;
      --portable) MODE="portable" ;;
      --force)    FORCE=1 ;;
      *) echo "error: unknown argument '$arg'" >&2; exit 2 ;;
   esac
done

if [[ "$MODE" == "system" ]]; then
   DEST="/c/Program Files/Git"
else
   DEST="$HOME/.local/zsh"
fi
ZSH_EXE="$DEST/usr/bin/zsh.exe"

# ---- already installed? ----
if [[ $FORCE -eq 0 && -x "$ZSH_EXE" ]]; then
   if "$ZSH_EXE" --version 2>/dev/null | grep -q "zsh $ZSH_VER"; then
      echo "zsh $ZSH_VER already installed at $ZSH_EXE"
      exit 0
   fi
fi

if [[ "$MODE" == "system" ]]; then
   if ! touch "$DEST/.zsh-write-test" 2>/dev/null; then
      echo "error: cannot write to $DEST -- run from an elevated shell, or" >&2
      echo "       omit --system to install into ~/.local/zsh instead." >&2
      exit 1
   fi
   rm -f "$DEST/.zsh-write-test"
fi

mkdir -p "$DEST"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> downloading $PKG"
curl -fsSL -o "$tmp/$PKG" "$URL"

echo "==> unpacking into $DEST"
"$TAR" -xf "$tmp/$PKG" -C "$DEST" \
   --exclude .BUILDINFO --exclude .INSTALL --exclude .MTREE --exclude .PKGINFO

echo "==> installed: $("$ZSH_EXE" --version)"
echo "==> WezTerm path: $(cygpath -w "$ZSH_EXE")"

if [[ "$MODE" == "portable" && ! -e "$HOME/.zshenv" ]]; then
   echo
   echo "note: ~/.zshenv is missing -- run ./install from the repo root so"
   echo "      dotbot links home/.zshenv, or zsh will not find its modules."
fi
