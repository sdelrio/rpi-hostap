# CI

Overview of the GitHub Actions workflows in `.github/workflows/`.

## E2E Test (`system-test.yml`)

The workflow display name is **E2E Test** (end-to-end): it boots real
mac80211_hwsim + hostapd + dnsmasq processes and exercises the full stack,
not just units. The file keeps the name `system-test.yml` because renaming
it changes no behavior but churns git history and breaks deep links.

The PR trigger label stays `system-test`: it is user-facing, referenced in
docs and existing PR workflows, so renaming it would break current usage.
No required checks reference this workflow by name, so no branch-protection
changes are needed. Artifact name: `e2e-debug-logs`. Concurrency group
prefix: `e2e-`. For the same history/link reasons, `tests/system_test.sh`
also keeps its filename.

### hwsim module cache and branch scoping

The workflow caches compiled wireless stack modules
(`/tmp/hwsim`) under key:

```
hwsim-modules-<os>-kernel-<uname -r>-<hash of .github/actions/build-hwsim-modules/action.yml>
```

Investigation of recent runs (32895001316, 32895972430, 32918439480,
32918739512, 32959609213) showed all used an **identical** cache key
(`hwsim-modules-Linux-kernel-6.17.0-1022-azure-<same hash>`), yet most
reported "Cache not found". This ruled out:

- Runner kernel churn: `6.17.0-1022-azure` was stable across all runs.
- Build recipe drift: the `hashFiles()` portion never changed.

Root cause: **GitHub Actions branch cache isolation**. The workflow runs on
`pull_request`, so each run executes in its own PR branch's cache scope. A
cache entry saved during PR A's run is invisible to PR B and to master, and
vice versa. `restore-keys` cannot cross branch scopes either, which is why
they are not used (in addition to the stale-module risk already noted in
the workflow).

### Mitigation: master-scope cache warmer

A second job in the same workflow, `warm-hwsim-cache`, builds the modules
on master and saves them under the exact same key format. It runs on
demand only: a manual `workflow_dispatch` with no `ref` input (no push
trigger, no cron schedule), typically after a runner kernel bump that
invalidates old entries via the `uname -r` key segment. PR runs restore
from whatever warm entry exists in master's scope; until a dispatch is
run they simply rebuild the modules locally.

Because PR runs inherit master's cache scope, entries saved by the warmer
are restorable by every PR run. The shared build recipe lives in the
composite action `.github/actions/build-hwsim-modules/`, used by both the
test job and the warmer.
