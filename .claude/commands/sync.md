Sync home config files between the repo and the user's home directory.

The sync direction is determined automatically — whichever copy was modified more recently wins.

## Files to sync

- `home/.wezterm.lua` ↔ `~/.wezterm.lua`
- `home/.bashrc` ↔ `~/.bashrc`

## Steps

1. For each file, compare modification times between the repo copy and the home copy using `stat`
2. If the files are identical (no diff), skip and say "already in sync"
3. If they differ, copy from the **newer** one to the older one
4. Show the diff of what changed before copying
5. Confirm which direction each file was synced (repo → home or home → repo)

## Notes

- These files have a `WEZTERM_CONFIG_DIR` variable at the top — never modify it during sync
- Use `cp` to copy, not move
- If the destination file doesn't exist yet, copy from whichever side has it
