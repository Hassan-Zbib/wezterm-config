# ============================================================
# Zsh Environment — WezTerm Setup
# ============================================================
# Managed by dotbot — run ./install from the repo to symlink.
#
# Read for EVERY zsh invocation (scripts included), so keep this minimal.
#
# zsh is installed into the Git for Windows tree (scripts/install-zsh.sh
# --system), so its compiled-in prefix of /usr resolves to the real thing and
# modules (zle, complete, ...) and completion functions are found natively. A
# portable install under ~/.local/zsh needed module_path and fpath redirected
# by hand here; that block is gone with the install that required it.
# ============================================================

# ------------------------------------------------------------
# MSYS PATH guard
# ------------------------------------------------------------
# A zsh spawned directly by a Win32 parent -- herdr, a scheduler, anything that
# is not WezTerm's `zsh -l` -- never runs /etc/profile, and /etc/profile is what
# puts the MSYS directories on PATH. Without them the shell has no coreutils at
# all: no mv, sed or tr, so compinit dies on its first `mv` and every plugin
# that shells out fails.
#
# herdr cannot fix this from its side. Its `shell_mode = "login"` silently
# spawns cmd.exe instead of the configured shell on native Windows (0.9.0,
# reproduced with both zsh and Git bash), so a login shell is simply not
# available there.
#
# Prepended, which is the order /etc/profile itself uses. A login shell already
# has /usr/bin on PATH, so the test fails and this is a no-op -- it only fires
# for the Win32-spawned case. Two builtin tests, no forks.
if [[ -x /usr/bin/ls && ":$PATH:" != *":/usr/bin:"* ]]; then
   path=(/usr/bin /mingw64/bin $path)
fi

# Nothing else belongs here. The portable install needed ~35 lines at this point
# to point module_path at ~/.local/zsh/usr/lib/zsh and to splice a cached,
# recursively-globbed functions tree onto fpath (the glob alone measured ~72ms
# on every single zsh invocation). With zsh inside the Git tree, zsh's own
# compiled-in prefix resolves to the same directories and both are found with
# no help and no cache to invalidate.
