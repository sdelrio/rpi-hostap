---
description: Loop over open GitHub issues (optional --label filter and --limit), addressing each in a subagent with a PR, waiting for manual review before merging.
---

# Loop over GitHub issues

Arguments: $ARGUMENTS

Parse `$ARGUMENTS` as optional flags (order-independent):
- `--label <label>`: only process issues with this GitHub label
- `--limit <n>`: process at most `n` issues. If not given, no limit —
  process all matching open issues.

Process the currently open issues in this repository (filtered by `--label`
if given, capped by `--limit` if given), one at a time, until none remain or
the limit is reached. For each issue:

1. **Sync**: `git checkout master && git pull` before starting any work.
2. **Fetch**: `gh issue view <number>` for details. Maintain a todo list of
   remaining issues; mark each `in_progress` when starting and add the
   `in_progress` label via `gh issue edit <n> --add-label in_progress`.
3. **Check existing PR first**: search open PRs (`gh pr list --state open`)
   for one referencing this issue. If a working PR exists, continue with it
   instead of creating a new one.
4. **Already done?** Check master for the implementation described in the
   issue's acceptance criteria. If already done and tested, just label it
   `done` (`gh issue edit <n> --remove-label in_progress --add-label done`)
   and move to the next issue.
5. **Delegate**: address the issue in a subagent (Task tool) that:
   - implements the fix/feature per the acceptance criteria
   - adds/updates bats tests and runs them locally until green
   - creates a feature branch (never commit to master directly)
   - commits with a conventional message referencing the issue number
   - writes the PR body to `tmp/pr-<n>.md` (per AGENTS.md) and opens the PR
     with `gh pr create --body-file tmp/pr-<n>.md`
   - watches checks with `gh pr checks <n> --watch`, pushing fixes until green
   - does NOT merge
6. **Pause for human review**: stop and report the PR URL, what changed, test
   results, and check status. Wait for the user to approve and merge (or tell
   you to merge). Do NOT merge on your own and do NOT start the next issue
   until the current one is merged.
7. **Finalize after merge**: squash-merge only if explicitly told
   (`gh pr merge <n> --squash --delete-branch`), then
   `gh issue edit <n> --remove-label in_progress --add-label done`,
   `git checkout master && git pull`, and continue with the next issue.

When no more matching open issues remain (or `--limit` is reached), summarize
every issue processed, its PR, and final status.

Usage examples:
- `/loop-issues` — all open issues, no limit
- `/loop-issues --label bugs` — only issues labeled `bugs`
- `/loop-issues --limit 3` — first 3 open issues
- `/loop-issues --label enhancement --limit 2`
