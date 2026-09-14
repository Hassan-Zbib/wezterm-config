Add a new winget tool to the repository. Arguments: $ARGUMENTS

## Parse the arguments

Extract the following from `$ARGUMENTS`:
- **Winget ID** (required) — e.g. `JesseDuffield.lazygit`
- **Display name** — e.g. `Lazygit` (derive from the ID if not given)
- **Description** — short one-liner, e.g. `Terminal UI for Git`
- **URL** — homepage or GitHub URL for README links
- **Alias** — shell alias used to invoke it (e.g. `lg`), or omit if none
- **Section** — `required` or `optional` (default: `optional`)

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

### 3. `scripts/cheatsheet.py`

The sheet is an interactive tabbed pager. CLI tools live on the `CLI` group pages, whose
panels are the `_FILE_TOOLS`, `_VIEWERS` and `_LAZY_TOOLS` constants. Add the tool to
whichever panel fits, using the existing builder calls:

```python
        blank() +
        sub('Tool Name') +
        row('alias or command', 'Description')  +
```

- `sub()` is the heading. Put the tool's real name in it — search indexes rows by the
  `sub()` above them, so `sub('zoxide (smart cd)')` is what makes `z DIR` findable by
  typing "zoxide".
- `row(key, desc)` per useful command. Keep `desc` short: the key column is padded to 22
  and the panel is 46 wide, and an over-long description silently corrupts the column grid.
- `note()` for prose caveats. Match the surrounding alignment style.

Do not add a new panel without checking `PAGES` — pages are capped at three panels so each
one stays a single screen at both 3 and 4 columns.

**Verify after editing:**

```sh
uv run python scripts/cheatsheet.py --selftest
```

## Rules

- Read each target file before editing it
- Do not add shell aliases to `.zshrc` or `.bashrc` — that's out of scope
- Do not add a cheatsheet entry if the tool has no meaningful CLI usage to show
- Run the cheatsheet `--selftest` after editing it
- After all edits, print a one-line summary per file changed
