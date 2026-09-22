#!/usr/bin/env bash
# ============================================================
# Fetch and verify the current WezTerm nightly installer
# ============================================================
# winget cannot be used to upgrade wez.wezterm.nightly:
#
#   winget upgrade --id wez.wezterm.nightly -e
#   ... Installer hash does not match; to override this check use
#       --ignore-security-hash
#
# The package points at the release tag `nightly`, which is rolling -- CI
# overwrites the same asset every night -- so the hash recorded in the manifest
# goes stale as soon as the next build lands and every upgrade fails. The only
# way through winget is --ignore-security-hash, which does not weaken one check,
# it removes the only one there is. Worse, the manifest's *version* is just as
# stale as its hash, so even when it works it can install a build several days
# older than what is actually published.
#
# This script goes straight to the release instead and does the verification
# winget would have done: download the installer, download the .sha256 that CI
# published beside it, compare, and refuse to hand over a file that does not
# match.
#
# What that does and does not buy you. The hash comes from the same host as the
# installer, so it cannot prove the release itself is honest -- TLS to
# github.com is the trust anchor for that, exactly as it is for winget on a
# fresh install. What it does catch is the thing that actually happens: a
# truncated or corrupted 45MB download landing as a plausible-looking .exe.
# That is strictly more than --ignore-security-hash checks, which is nothing.
# (Contrast scripts/install-zsh.sh, where the hash is a pinned constant in the
# repo because the mirror there is untrusted and unsigned. Pinning is not an
# option for a rolling nightly: the file legitimately changes every day.)
#
# Running the installer is left to you by default. It needs admin, and it
# replaces binaries that the WezTerm you are reading this in has open, so it
# wants every WezTerm window closed first -- not something to do behind your
# back from inside one of those windows. --install launches it interactively
# when you are ready.
#
# Usage:
#   ./wezterm-upgrade.sh              # download + verify, print where it is
#   ./wezterm-upgrade.sh --install    # ... then launch the installer
#   ./wezterm-upgrade.sh --force      # re-download even if already verified
#   ./wezterm-upgrade.sh --dir DIR    # somewhere other than ~/Downloads
#
# F1 in WezTerm shows the installed build, the published one and the changelog
# in between. This script deliberately does not repeat that: it always fetches
# whatever is currently published.
# ============================================================
set -euo pipefail

BASE="https://github.com/wezterm/wezterm/releases/download/nightly"
ASSET="WezTerm-nightly-setup.exe"
RELEASE_PAGE="https://github.com/wezterm/wezterm/releases/tag/nightly"

INSTALL=0
FORCE=0
DEST_DIR="$HOME/Downloads"

while [[ $# -gt 0 ]]; do
   case "$1" in
      --install) INSTALL=1 ;;
      --force)   FORCE=1 ;;
      --dir)
         [[ $# -ge 2 ]] || { echo "error: --dir needs a path" >&2; exit 2; }
         DEST_DIR="$2"; shift
         ;;
      -h|--help) sed -n '2,49p' "$0" | sed 's/^# \?//'; exit 0 ;;
      *) echo "error: unknown argument '$1'" >&2; exit 2 ;;
   esac
   shift
done

# Same reasoning as scripts/cheatsheet.py: $WEZTERM_EXECUTABLE is whichever
# binary owns this pane, and in a normal window that is wezterm-gui.exe, which
# answers --version with "someone forgot to call assign_version_info". Its
# sibling wezterm.exe reports properly.
wezterm_version() {
   local dir="${WEZTERM_EXECUTABLE_DIR:-}"
   local cand
   for cand in "${dir:+$dir/wezterm.exe}" wezterm; do
      [[ -n "$cand" ]] || continue
      if out="$("$cand" --version 2>/dev/null)"; then
         if [[ "$out" =~ [0-9]{8}-[0-9]{6}-[0-9a-f]{7,} ]]; then
            echo "${BASH_REMATCH[0]}"
            return 0
         fi
      fi
   done
   return 1
}

# Hard-fail rather than degrade: a missing sha256sum must not quietly turn a
# verified download into an unverified one. It ships with Git for Windows.
if ! command -v sha256sum >/dev/null 2>&1; then
   echo "error: sha256sum not found -- cannot verify $ASSET, refusing." >&2
   exit 1
fi

installed="$(wezterm_version || true)"
echo "==> installed: ${installed:-unknown}"

echo "==> published: $RELEASE_PAGE"
# The rolling tag carries no version, so the asset's mtime is the only thing
# that says how fresh the build is. Same value the F1 page reports.
built="$(curl -fsSLI "$BASE/$ASSET" 2>/dev/null \
         | tr -d '\r' | grep -i '^last-modified:' | tail -1 | cut -d' ' -f2-)"
[[ -n "$built" ]] && echo "    built $built"

echo "==> fetching published checksum"
want="$(curl -fsSL "$BASE/$ASSET.sha256" | tr -d '\r' | cut -d' ' -f1)"
if [[ ! "$want" =~ ^[0-9a-f]{64}$ ]]; then
   echo "error: $ASSET.sha256 did not contain a sha256 -- got '${want:0:80}'" >&2
   exit 1
fi
echo "    $want"

mkdir -p "$DEST_DIR"
target="$DEST_DIR/$ASSET"

# Fed on stdin, not by path: given a filename containing backslashes -- which
# is what a Windows-style $HOME produces -- sha256sum switches to its
# escaped-filename form and prefixes the line with '\', which lands in the hash
# field and fails the compare on a perfectly good file.
file_hash() { sha256sum < "$1" | cut -d' ' -f1; }

if [[ $FORCE -eq 0 && -f "$target" ]] && [[ "$(file_hash "$target")" == "$want" ]]; then
   echo "==> already downloaded and verified, reusing it"
else
   echo "==> downloading $ASSET"
   # To a temp name first: a failed or interrupted download must not leave
   # something that looks installable sitting in Downloads.
   tmp="$(mktemp -d)"
   trap 'rm -rf "$tmp"' EXIT
   curl -fL --progress-bar -o "$tmp/$ASSET" "$BASE/$ASSET"

   echo "==> verifying checksum"
   got="$(file_hash "$tmp/$ASSET")"
   if [[ "$got" != "$want" ]]; then
      echo "error: checksum mismatch -- REFUSING to keep this download." >&2
      echo "  expected: $want" >&2
      echo "  got:      $got" >&2
      echo "Most likely a corrupted or truncated transfer; re-run to retry." >&2
      echo "If it keeps failing, CI may have replaced the asset mid-download," >&2
      echo "in which case the checksum you fetched is for the older build." >&2
      exit 1
   fi
   mv -f "$tmp/$ASSET" "$target"
   echo "    ok"
fi

win_target="$(cygpath -w "$target")"
echo
echo "==> verified installer: $win_target"

if [[ $INSTALL -eq 0 ]]; then
   cat <<EOF

To install:
  1. Close every WezTerm window (the installer replaces binaries this one has
     open). Save anything running in a pane first.
  2. Run the installer -- it will prompt for admin:
       "$win_target"
  3. Reopen WezTerm and press F1 to confirm the new build.

Or re-run with --install to launch it from here.
EOF
   exit 0
fi

echo
echo "!!  The installer replaces the WezTerm binaries this shell is running"
echo "!!  inside. Close your other WezTerm windows before continuing, and"
echo "!!  expect this one to need a restart afterwards."
echo
read -r -p "Launch the installer now? [y/N] " reply
case "$reply" in
   [yY]|[yY][eE][sS]) ;;
   *) echo "Left it at $win_target"; exit 0 ;;
esac

echo "==> launching the installer (it will prompt for admin)"
# Interactively, with no /SILENT: Inno Setup needs to be able to tell you about
# files that are still in use, and a leading-slash argument would get mangled
# into a Windows path by the MSYS argument converter anyway.
"$target"

echo
echo "==> wezterm.exe now reports: $(wezterm_version || echo unknown)"
echo "    Restart WezTerm to actually run it, then press F1 to confirm."
