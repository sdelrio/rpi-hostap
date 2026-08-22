# Agent Task Management

## Source of Truth
GitHub issues are the single source of truth for all pending tasks in this repository. The agent should:
1. Check GitHub issues for work to be done
2. Update issue status via labels as work progresses
3. Reference issue numbers in commits/PRs

## Issue Status Labels (Workflow)

### Issue Lifecycle Labels
These control workflow status:
- `ready`: Issue is prepared for work to begin
- `in_progress`: Issue is currently being worked on
- `done`: Issue completed successfully

### Issue Type Labels
These categorize the nature of the issue:
- `bugs`: Defect/fix issue
- `security`: Security-related issue
- `enhancement`: Feature request/improvement
- `minor`: Minor cleanup/nit issue

## Kanban Workflow
### Moving Issues Between States

To move a GitHub issue from one status to another:

1. **Backlog → Ready** (start work):
   - Use `gh issue edit <issue-number> --add-label ready` or navigate to the project board in GitHub
   - The `ready` label indicates the issue is prepared for work to begin

2. **Ready → In Progress**:
   - Use `gh issue edit <issue-number> --add-label in_progress`
   - When starting work, mark the issue as `in_progress`

3. **In Progress → Done**:
   - Use `gh issue edit <issue-number> --remove-label in_progress` (and optionally `--add-label done`)

### Label to State Mapping

| Label | GitHub Status | Work State |
|-------|---------------|------------|
| `ready` | Backlog → Ready | Work begins |
| `in_progress` | Ready → In Progress | Currently working |
| `done` | In Progress → Done | Complete |

### Workflow Steps
1. When starting work: Move issue from `ready` to `in_progress` (add `in_progress` label)
2. When completing work: Remove `in_progress` label, optionally add `done` label
3. Agent should always check GitHub issues before beginning work
4. **Never push to master directly**: Always prepare a Pull Request for review
5. **Pin GitHub Actions to SHA**: All actions in workflow files must use full-length commit SHAs (e.g., `uses: actions/checkout@<sha> # v7.0.1`). This is enforced by repository rules. To find an action's SHA: `gh api repos/<owner>/<repo>/tags --jq '.[0].commit.sha'`

## Creating Issues and PRs (body-file pattern)

When creating issues or PRs with `gh`, do **not** pass long markdown inline via `--body` (it requires escaping backticks, quotes, `$`, etc. and breaks in shell heredocs). Instead:

1. Write the body to a temporary file using the Write tool, e.g. `/var/folders/<tmp>/opencode/issue-<slug>.md`
2. Create the issue/PR referencing it:

```bash
gh issue create --title "Title here" --label "minor" --body-file /path/to/body.md
gh pr create --title "Title here" --body-file /path/to/body.md
```

This avoids all character escaping issues.