Commit all current changes to the repository.

## Steps

1. Run `git status` to review changes (never use `-uall`)
2. Run `git diff` to review unstaged changes
3. Stage only relevant files by name — never use `git add -A` or `git add .`
   - Never stage `.env`, credentials, `sessions.json`, or other sensitive/generated files
4. Write a commit message using conventional commits:
   - Format: `type: summary` (under 72 chars, lowercase, no period)
   - Types: `feat`, `fix`, `chore`, `refactor`, `style`, `docs`, `perf`, `ci`, `test`
   - If multiple changes: add a blank line then single-line bullet points
   - Never add `Co-Authored-By` or any trailer lines
5. Run `git add <file1> <file2> ...` — stage all relevant files in a single command
6. For single-line messages use `git commit -m "..."`. For multi-line use a HEREDOC
7. Run `git status` after to verify success

## Rules

- Never amend existing commits unless explicitly asked
- Never force push
- If a pre-commit hook fails, fix the issue and create a NEW commit
- If there are no changes, say so — don't create empty commits
- Run each git command as a separate Bash call — never chain with `&&` or `;`
- Never use `cd "..." && git ...` — always run git commands from the repo root directly (Claude Code sets the working directory automatically)
