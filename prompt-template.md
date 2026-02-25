You are fixing issues on PR #{{PR_NUMBER}} on branch `{{BRANCH}}`.
Repository: {{REPO}}. Only modify files in this PR's diff.

## Review Comments Requesting Changes
{{REVIEW_COMMENTS}}

## CI Test Failures
{{CI_FAILURES}}

## Documentation Feedback
{{DOC_COMMENTS}}

## PR Diff
{{DIFF}}

## Rules
1. Fix each issue. Be minimal — only change what's needed.
2. If test commands are available, run them on changed files.
3. If a linter config exists, run linting on changed files.
4. Do NOT commit or push — the caller handles that.
5. Output a markdown summary of changes (## Summary section).
