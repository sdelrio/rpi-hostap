# Agent Task Management

## lib/ Layering Rule (issue #240)

`lib/` is split into two layers:

- `lib/core/`: pure modules (validation.sh, dhcp.sh, channel.sh, wpa.sh, stations.sh, mac_filter.sh, env.sh, lifecycle.sh, ctrl_interface.sh, client_env.sh, ap_isolation.sh, extra_opts.sh, passphrase.sh, secret_file.sh, ssid_hidden.sh, warnings.sh). Core modules must NOT invoke external system commands (`iptables`, `ip`, `iw`, `sysctl`, `hostapd_cli`, `dnsmasq`, ...) or touch `/proc`. Their bats tests run anywhere without stubs.
- `lib/sys/`: effectful modules (nat.sh, ipv6.sh, interface.sh, radio.sh, atomic.sh, log.sh, logging.sh). All system interaction goes here. Tests use existing stub patterns (`SYSCTL_BASE`, `IPV6_SYSCTL_BASE`, overridable commands).

Enforcement: `make layer-check` plus `tests/layering.bats`; both are run in CI.

## Writing Style

- Never use the em dash "—". Use plain dash "-" instead.

## Bash Function Naming Convention

All functions in `lib/*.sh` must follow the `<module>_<verb>` convention, where `<module>` is the library filename without `.sh` (e.g. `nat_parse_outgoings`, `ipv6_apply_rules`, `validation_netmask_to_prefix`). Private helpers use a leading underscore plus the module prefix (e.g. `_log_emit`). The bare `log()` function in `lib/sys/log.sh` is an accepted exception since it is the module's own namespace. Entry-point scripts at the repo root (`wlanstart.sh`, `clients.sh`, `healthcheck.sh`) follow the same rule for their helper functions (`clients_emit_json`, `wlanstart_cleanup`); small script-local handlers like `cleanup`, `handle_signal`, and `check_interrupted` are exempt. Do not create name collisions between modules.

## Temporary Files

Write all temporary files (PR bodies, issue bodies, scratch files, etc.) to `<repo-root>/tmp/`, e.g. `tmp/pr-<slug>.md`. This directory is gitignored; never use `/tmp` or other system paths.

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
5. **Always merge PRs with squash** (`gh pr merge <number> --squash`): this repo does not allow merge commits, and squash keeps history linear with one conventional commit per PR
6. **Pin GitHub Actions to SHA**: All actions in workflow files must use full-length commit SHAs (e.g., `uses: actions/checkout@<sha> # v7.0.1`). This is enforced by repository rules. To find an action's SHA: `gh api repos/<owner>/<repo>/tags --jq '.[0].commit.sha'`

## Creating Issues and PRs (body-file pattern)

When creating issues or PRs with `gh`, do **not** pass long markdown inline via `--body` (it requires escaping backticks, quotes, `$`, etc. and breaks in shell heredocs). Instead:

1. Write the body to a temporary file using the Write tool, e.g. `/var/folders/<tmp>/opencode/issue-<slug>.md`
2. Create the issue/PR referencing it:

```bash
gh issue create --title "Title here" --label "minor" --body-file /path/to/body.md
gh pr create --title "Title here" --body-file /path/to/body.md
```

This avoids all character escaping issues.

## Waiting for PR Checks

When waiting for CI checks on a pull request, use `gh pr checks <number> --watch` instead of sleeping and polling:

```bash
gh pr checks 70 --watch
```

If no checks are reported yet, retry after a short delay until runs appear, then use `--watch`.

## Commit Messages and PR Titles (Semantic Release)

All commit messages and PR titles must follow the [Conventional Commits](https://www.conventionalcommits.org/) / semantic release format:

```
<type>(<optional scope>): <description>
```

Common types:
- `feat`: new feature (triggers minor version bump)
- `fix`: bug fix (triggers patch version bump)
- `docs`: documentation only
- `refactor`: code change that neither fixes a bug nor adds a feature
- `chore`: maintenance, tooling, CI changes
- `test`: adding or correcting tests

Examples:

```bash
git commit -m "fix: correct typo in wlanstart.sh comments"
gh pr create --title "feat(hostapd): add AP isolation support"
```

Breaking changes should use `!` after the type (e.g., `feat!:`) and trigger a major version bump.