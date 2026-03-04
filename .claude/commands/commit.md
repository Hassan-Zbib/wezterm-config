Commit all current changes to the repository.

## Steps

1. Run `git status` (never use `-uall`) and `git diff` to review all staged and unstaged changes
2. Stage only relevant files by name — never use `git add -A` or `git add .`
   - Never stage `.env`, credentials, `sessions.json`, or other sensitive/generated files
3. Write a commit message using conventional commits:
   - Format: `type: summary` (under 72 chars, lowercase, no period)
   - Types: `feat`, `fix`, `chore`, `refactor`, `style`, `docs`, `perf`, `ci`, `test`
   - If multiple changes: add a blank line then single-line bullet points
   - Never add `Co-Authored-By` or any trailer lines
4. For single-line messages use `git commit -m "..."`. For multi-line messages use a HEREDOC
5. Run `git status` after to verify success

## Rules

- Never amend existing commits unless explicitly asked
- Never force push
- If a pre-commit hook fails, fix the issue and create a NEW commit
- If there are no changes, say so — don't create empty commits
