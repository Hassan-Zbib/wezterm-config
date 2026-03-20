-- ============================================================
-- Yazi Plugins
-- ============================================================
-- Managed by dotbot — run ./install from the repo to symlink.
-- Requires:
--   ya pack -a yazi-rs/plugins:git
--   ya pack -a Rolv-Apneseth/starship.yazi
-- ============================================================

-- Git status indicators in the file list
require("git"):setup()

-- Starship in the status bar (uses ~/.config/starship.toml)
require("starship"):setup()
