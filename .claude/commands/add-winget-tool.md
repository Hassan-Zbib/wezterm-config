Add a new winget tool to the repository. Arguments: $ARGUMENTS

## Parse the arguments

Extract the following from `$ARGUMENTS`:
- **Winget ID** (required) — e.g. `JesseDuffield.lazygit`
- **Display name** — e.g. `Lazygit` (derive from the ID if not given)
- **Description** — short one-liner, e.g. `Terminal UI for Git`
- **URL** — homepage or GitHub URL for README links
- **Alias** — bash alias used to invoke it (e.g. `lg`), or omit if none
- **Section** — `required` or `optional` (default: `optional`)
- **Type** — `tui` if it's a terminal UI app that should be session-restorable, otherwise omit

If the winget ID is missing, stop and ask. For anything else that can't be inferred, ask before editing.

## Files to update

### 1. `install.conf.yaml`

Add the winget ID under the `- winget:` block:
- `required` tools → under the `# required` comment
- `optional` tools → under the `# optional CLI tools` comment

### 2. `README.md`

- If **required**: add a row to the Prerequisites table (`| Tool | Install |` format)
- If **optional**: add a row to the Optional CLI Tools table (`| Tool | Install | Alias | Description |` format)

Link the tool name to its URL. The Install column should show the bare `winget install <ID>` command.
If the tool has no alias, use `—` in that column.

### 3. `scripts/cheatsheet.sh`

Add a block to the tools column (COL_LEFT in the Row 3 section), following the existing style exactly:

```bash
sec_blank
sec_header "EMOJI  Tool Name"
sec_row "alias or command"   "Description"
```

Pick an emoji that fits the tool's purpose. If the tool has multiple useful commands or flags worth showing, add multiple `sec_row` lines. Match the spacing/quoting style of the existing blocks.

### 4. `utils/sessions.lua` (TUI tools only)

If the tool type is `tui`, add an entry to the `M.tuis` table. The key is the process basename
(lowercase, no `.exe`) as it appears in the process list. The value is the launch command string.
If the winget package installs under a different executable name than the display name, use the
actual executable name as the key (e.g. `btop4win = 'btop'`).

Follow the existing `-- stylua: ignore` alignment style — pad with spaces so the `=` signs line up
with the other entries.

## Rules

- Read each target file before editing it
- Do not add bash aliases to `.bashrc` — that's out of scope
- Do not add a cheatsheet entry if the tool has no meaningful CLI usage to show
- After all edits, print a one-line summary per file changed
