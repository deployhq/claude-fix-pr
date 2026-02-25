---
description: "Fix PR issues from review comments, test failures, and missing docs"
argument-hint: "[PR number]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - AskUserQuestion
---

Fix issues on a pull request based on review comments, CI failures, and documentation feedback.

## Steps

1. **Guard: refuse protected branches**

Check the current branch. If it is `main`, `master`, or `staging`, stop immediately and tell the user:
> "Refusing to run on protected branch `{branch}`. Switch to a feature branch first."

```bash
CURRENT_BRANCH=$(git branch --show-current)
```

2. **Determine PR number**

If `$ARGUMENTS` contains a number, use that as the PR number. Otherwise, detect it:

```bash
gh pr view --json number -q .number
```

If no PR is found for the current branch, tell the user and stop.

3. **Gather PR context**

Run the shared context-gathering script. If the plugin is installed locally, use the local copy. Otherwise fetch from GitHub:

```bash
# Try local path first (plugin install directory)
SCRIPT_DIR="$(dirname "$(dirname "$0")")/scripts"
if [[ -f "$SCRIPT_DIR/gather-pr-context.sh" ]]; then
  PROMPT=$(bash "$SCRIPT_DIR/gather-pr-context.sh" "$PR_NUMBER")
else
  PROMPT=$(bash <(curl -sL "https://raw.githubusercontent.com/deployhq/claude-fix-pr/main/scripts/gather-pr-context.sh") "$PR_NUMBER")
fi
```

4. **Analyze and fix issues**

Using the gathered context as your guide:

- Read each review comment and understand what change is requested
- Check CI failures and identify the root cause in the code
- Look at documentation feedback and fix any issues
- Make minimal, targeted changes — only modify files in the PR's diff
- If test commands exist (`bin/rspec`, `rubocop`, `go test`, etc.), run them on changed files to verify fixes

5. **Show summary**

After making fixes, show the user what changed:

```bash
git diff
git diff --stat
```

Present a brief summary of what was fixed and why.

6. **Confirm before committing**

Ask the user:
> "I've made the above changes to fix PR feedback. Would you like me to commit and push these changes?"

Options:
- **Yes, commit and push** — Commit with message `fix: address PR feedback for #<PR_NUMBER>` and push
- **Just commit, don't push** — Commit only
- **No, I'll review first** — Leave changes unstaged for manual review

If there are no changes to make, tell the user: "No issues found — the PR looks good!"
