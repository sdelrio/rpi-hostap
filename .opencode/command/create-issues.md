---
description: Create GitHub issues from a reviewed list of fixes/improvements/features
agent: build
---

Create GitHub issues for each item from a previously reviewed suggestions list (see /review-project). Ask the user which items to include if no list was just produced.

## Rules

- **Issue bodies must be written to temporary markdown files first** (one per issue) under `<repo-root>/tmp/` (this directory is gitignored per AGENTS.md), then passed via `--body-file`. Never pass long markdown inline with `--body`.
- One issue per item; do not merge unrelated items.

## Steps

For each selected item:

1. Write the issue body to `tmp/issue-<slug>.md`. Body should contain:
   - `## Problem` — what is wrong / what is missing, with `file:line` references
   - `## Proposed fix` (or `## Proposed design`) — concrete approach, code sketches where helpful
   - `## Acceptance criteria` — checklist of verifiable outcomes
2. Create the issue:
   ```bash
   gh issue create --title "<type>: <description>" --label "<labels>" --body-file tmp/issue-<slug>.md
   ```
3. Titles follow Conventional Commits style (`fix: ...`, `feat: ...`, `enhancement: ...`, `docs: ...`).
4. Labels by category:
   - Bug fix → `bugs`
   - Improvement/refactor → `enhancement` (add `minor` if trivial)
   - New feature → `enhancement`
   - Docs only → `minor`

## Output

Report each created issue number + URL grouped by category.
