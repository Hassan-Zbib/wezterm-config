# ============================================================
# Zsh Environment — WezTerm Setup
# ============================================================
# Managed by dotbot — run ./install from the repo to symlink.
#
# Read for EVERY zsh invocation (scripts included), so keep this minimal.
#
# zsh lives in the Git for Windows tree (scripts/install-zsh.sh), so its
# compiled-in /usr prefix resolves natively and modules and completion functions
# are found with no module_path or fpath help.
# ============================================================

# ------------------------------------------------------------
# MSYS PATH guard
# ------------------------------------------------------------
# A zsh spawned by a Win32 parent -- a scheduler, anything that is not
# WezTerm's `zsh -l` -- never runs /etc/profile, which is what puts the MSYS
# directories on PATH. Without them there are no coreutils at all: compinit dies
# on its first `mv` and every plugin that shells out fails.
#
# Prepended, matching /etc/profile's own order. A login shell already has
# /usr/bin on PATH, so this is a no-op there. Two builtin tests, no forks.
if [[ -x /usr/bin/ls && ":$PATH:" != *":/usr/bin:"* ]]; then
   path=(/usr/bin /mingw64/bin $path)
fi
