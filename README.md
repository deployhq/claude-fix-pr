# claude-fix-pr

Fix PR issues (review comments, test failures, missing docs) using Claude Code. Works as both a **local CLI plugin** and a **reusable GitHub Action**.

## Installation

### As a Claude Code Plugin (local development)

```bash
claude plugin install deployhq/claude-fix-pr
```

Then in any repo with a PR:

```bash
/fix-pr           # fixes current branch's PR
/fix-pr 123       # fixes PR #123
```

### As a GitHub Action (CI automation)

Add `.github/workflows/fix-pr.yml` to your repo:

```yaml
name: Fix PR
on:
  check_suite:
    types: [completed]
  issue_comment:
    types: [created]

jobs:
  fix-pr:
    uses: deployhq/claude-fix-pr/.github/workflows/fix-pr.yml@main
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

That's it. The action will:
- **Auto-trigger** when CI fails on a PR branch
- **Manual trigger** when someone comments `/fix-pr` on a PR
- **Skip** protected branches (main, master, staging)

## How It Works

1. **Gathers context** — review comments, CI failures, documentation feedback, and PR diff using `gh` CLI
2. **Builds a prompt** — fills a shared template with all gathered context
3. **Runs Claude** — Claude reads the context and makes targeted fixes
4. **Reports back** — commits changes and posts a summary comment on the PR

## What It Fixes

- **Review comments** — inline code review feedback and conversation comments
- **CI failures** — test failures, linting errors, type check issues
- **Documentation** — typos, missing docs, outdated comments

## Safety

- Only modifies files in the PR's diff
- Refuses to run on protected branches (main, master, staging)
- Tool access is scoped — Claude can only read, edit, and run tests/linters
- In local mode, asks for confirmation before committing
- In CI mode, commits are attributed to `claude-fix-pr[bot]`

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) — for local plugin use
- `ANTHROPIC_API_KEY` — set as environment variable (local) or GitHub secret (CI)

## Repository Structure

```
.claude-plugin/plugin.json    — Plugin metadata
commands/fix-pr.md            — Local /fix-pr slash command
agents/pr-fixer.md            — Subagent for complex fixes
scripts/gather-pr-context.sh  — Context gathering (shared by CLI and CI)
prompt-template.md            — Prompt template (shared by CLI and CI)
.github/workflows/fix-pr.yml  — Reusable GitHub Action workflow
```

## Configuration

### Customizing triggers (GitHub Action)

The reusable workflow responds to `check_suite` (auto) and `issue_comment` (manual). To limit triggers, override in your calling workflow:

```yaml
on:
  issue_comment:
    types: [created]   # manual only — no auto-trigger on CI failure

jobs:
  fix-pr:
    uses: deployhq/claude-fix-pr/.github/workflows/fix-pr.yml@main
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Adding custom test commands

The workflow allows Claude to run common test commands (`bin/rspec`, `rubocop`, `go test`, `yarn test`, `npm test`). To add more, fork the workflow and extend the `--allowedTools` list.

## License

MIT
