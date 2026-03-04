Push the current branch to the remote repository.

## Steps

1. Run `git status` to confirm there are no uncommitted changes — if there are, warn and stop
2. Run `git log origin/main..HEAD --oneline` to show what will be pushed
3. If there are no unpushed commits, say so and stop
4. Push to the remote with `git push`
5. Confirm success with the remote URL and commit range

## Rules

- Never force push (`--force` or `--force-with-lease`) unless explicitly asked
- Never push to main/master with `--force` even if asked — warn instead
- If the push is rejected (behind remote), suggest `git pull --rebase` first
