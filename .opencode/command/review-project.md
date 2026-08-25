---
description: Review the project and suggest features, improvements and fixes
agent: build
---

Review this project and produce a structured list of suggested work items.

## Steps

1. Read `SPEC.md` first - it is the reference for what the project must do; findings should be checked against it (violations are bugs, gaps are features).
2. Explore the repository: README, entrypoint/startup scripts, Dockerfile, healthcheck, `lib/`, `scripts/`, `.github/` workflows and tests.
3. Check open GitHub issues to avoid suggesting duplicates:
   ```bash
   gh issue list --state open --limit 50
   ```
4. Analyze the code for:
   - **Bugs**: race conditions, incorrect shell logic (e.g. `wait` semantics), missing validation, unclean teardown, error handling gaps, deviations from SPEC.md requirements.
   - **Improvements**: robustness of healthchecks, better error messages, code structure following the existing `lib/*.sh` + bats tests pattern.
   - **Features**: useful new capabilities consistent with the project's purpose and not excluded by SPEC.md's non-goals.
   - **Docs**: undocumented env vars or behavior gaps in the README.

## Output format

Present findings grouped as:

- **Fixes (bugs)** - numbered, each with file:line references and a short explanation of the problem and proposed fix.
- **Improvements** - numbered, same detail level.
- **Features** - numbered, with a brief design sketch.

Do NOT create any issues yet - wait for explicit confirmation from the user.
