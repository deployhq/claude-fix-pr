#!/usr/bin/env bash
set -euo pipefail

# gather-pr-context.sh — Gathers PR context and fills the prompt template.
# Usage: gather-pr-context.sh <PR_NUMBER> [REPO]
#
# Requires: gh CLI authenticated

PR_NUMBER="${1:?Usage: gather-pr-context.sh <PR_NUMBER> [REPO]}"
REPO="${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="${TEMPLATE_PATH:-$SCRIPT_DIR/../prompt-template.md}"

# If running from curl (no local template), fetch it
if [[ ! -f "$TEMPLATE_PATH" ]]; then
  TEMPLATE=$(curl -s "https://raw.githubusercontent.com/deployhq/claude-fix-pr/main/prompt-template.md")
else
  TEMPLATE=$(cat "$TEMPLATE_PATH")
fi

# --- Gather branch name ---
BRANCH=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json headRefName -q .headRefName)

# --- Gather inline review comments (code-level) ---
REVIEW_COMMENTS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/comments" \
  --jq '.[] | select(.user.login != "github-actions[bot]" and .user.login != "claude-fix-pr[bot]") | "File: \(.path):\(.line // .original_line // "N/A")\nReviewer: \(.user.login)\n\(.body)\n---"' \
  2>/dev/null || echo "None found.")

# --- Gather PR conversation comments ---
PR_COMMENTS=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json comments \
  --jq '.comments[] | select(.author.login != "github-actions[bot]" and .author.login != "claude-fix-pr[bot]") | "Author: \(.author.login)\n\(.body)\n---"' \
  2>/dev/null || echo "None found.")

# Merge review + conversation comments
if [[ "$REVIEW_COMMENTS" == "None found." && "$PR_COMMENTS" == "None found." ]]; then
  ALL_COMMENTS="No review comments found."
else
  ALL_COMMENTS=""
  if [[ "$REVIEW_COMMENTS" != "None found." ]]; then
    ALL_COMMENTS+="### Inline Code Review Comments\n$REVIEW_COMMENTS\n\n"
  fi
  if [[ "$PR_COMMENTS" != "None found." ]]; then
    ALL_COMMENTS+="### PR Conversation Comments\n$PR_COMMENTS"
  fi
fi

# --- Gather failed CI checks ---
CI_FAILURES=""
FAILED_CHECKS=$(gh pr checks "$PR_NUMBER" --repo "$REPO" --json name,state,bucket,detailsUrl \
  --jq '[.[] | select(.bucket == "fail")]' 2>/dev/null || echo "[]")

FAIL_COUNT=$(echo "$FAILED_CHECKS" | jq 'length')

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  CI_FAILURES="### Failed Checks\n"
  while IFS= read -r check_name; do
    CI_FAILURES+="- **$check_name**\n"

    # Try to get run ID and fetch failed logs
    DETAILS_URL=$(echo "$FAILED_CHECKS" | jq -r ".[] | select(.name == \"$check_name\") | .detailsUrl")
    RUN_ID=$(echo "$DETAILS_URL" | grep -oP 'runs/\K[0-9]+' 2>/dev/null || true)

    if [[ -n "$RUN_ID" ]]; then
      FAILED_LOG=$(gh run view "$RUN_ID" --repo "$REPO" --log-failed 2>/dev/null | tail -100 || true)
      if [[ -n "$FAILED_LOG" ]]; then
        CI_FAILURES+="\`\`\`\n$FAILED_LOG\n\`\`\`\n"
      fi
    fi
  done < <(echo "$FAILED_CHECKS" | jq -r '.[].name')
else
  CI_FAILURES="No CI failures detected."
fi

# --- Gather documentation-related comments ---
DOC_COMMENTS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/comments" \
  --jq '.[] | select(.body | test("(?i)(doc|readme|comment|jsdoc|rdoc|yard|annotation|typo|spelling)")) | "File: \(.path):\(.line // "N/A")\nReviewer: \(.user.login)\n\(.body)\n---"' \
  2>/dev/null || echo "No documentation feedback found.")

# --- Gather PR diff ---
DIFF=$(gh pr diff "$PR_NUMBER" --repo "$REPO" 2>/dev/null || echo "Could not retrieve diff.")

# Truncate diff if too large (>50K chars) to stay within context limits
if [[ ${#DIFF} -gt 50000 ]]; then
  DIFF="${DIFF:0:50000}

... [diff truncated at 50K chars — full diff available via \`gh pr diff $PR_NUMBER\`]"
fi

# --- Fill template using temp files (safe for multi-line content) ---
TMPDIR_CTX=$(mktemp -d)
trap 'rm -rf "$TMPDIR_CTX"' EXIT

echo "$TEMPLATE" > "$TMPDIR_CTX/template"
echo "$ALL_COMMENTS" > "$TMPDIR_CTX/review_comments"
echo "$CI_FAILURES" > "$TMPDIR_CTX/ci_failures"
echo "$DOC_COMMENTS" > "$TMPDIR_CTX/doc_comments"
echo "$DIFF" > "$TMPDIR_CTX/diff"

python3 -c "
import os, sys
d = sys.argv[1]
with open(os.path.join(d, 'template')) as f:
    t = f.read()
replacements = {
    '{{PR_NUMBER}}': '$PR_NUMBER',
    '{{BRANCH}}': '$BRANCH',
    '{{REPO}}': '$REPO',
}
for placeholder, value in replacements.items():
    t = t.replace(placeholder, value)
file_replacements = {
    '{{REVIEW_COMMENTS}}': 'review_comments',
    '{{CI_FAILURES}}': 'ci_failures',
    '{{DOC_COMMENTS}}': 'doc_comments',
    '{{DIFF}}': 'diff',
}
for placeholder, filename in file_replacements.items():
    with open(os.path.join(d, filename)) as f:
        t = t.replace(placeholder, f.read().strip())
print(t)
" "$TMPDIR_CTX"
