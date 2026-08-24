# CI

## Release Please Workflow

The workflow lives in `.github/workflows/release-please.yml`.

### How It Works

1. Push [conventional commits](https://www.conventionalcommits.org/) (`fix:`, `feat:`, `BREAKING CHANGE:`) to `master`
2. Release Please automatically creates/updates a **Release PR** with:
   - Version bump in `.release-please-manifest.json`
   - Changelog entries from commit messages
3. Review and merge the Release PR
4. Merging creates a **GitHub Release** with a version tag
5. The Publish workflow triggers and builds/pushes Docker images to DockerHub and GHCR

```
fix: foo       ─┐
feat: bar      ─┼─▶ push to master ─▶ Release PR created ─▶ merge PR ─▶ GitHub Release ─▶ publish images
feat!: baz     ─┘
```

### Making a Release

Releases are made by merging the Release PR. No manual tagging required.

### Upgrading to v1.0.0

To jump from a pre-1.0 version (e.g., `0.31.0`) to `1.0.0`:

1. Update `.release-please-manifest.json`:
   ```json
   {
     ".": "1.0.0"
   }
   ```

2. Open a Pull Request with the change (never push to `master` directly) and merge it:
   ```bash
   git checkout -b chore/release-v1.0.0
   git add .release-please-manifest.json
   git commit -m "chore: release v1.0.0"
   git push -u origin chore/release-v1.0.0
   gh pr create --title "chore: release v1.0.0" --fill
   ```

## Release Please Version Bumping

### `bump-minor-pre-major: false` / `bump-patch-for-minor-pre-major: false` (current)

| Commit type | Version bump | Example |
|-------------|-------------|---------|
| `fix:` | patch | 0.5.0 → 0.5.1 |
| `feat:` | minor | 0.5.0 → 0.6.0 |
| `BREAKING CHANGE:` | major | 0.5.0 → 1.0.0 |

### `bump-minor-pre-major: true` / `bump-patch-for-minor-pre-major: true`

Not currently enabled; shown for reference only.

| Commit type | Version bump | Example |
|-------------|-------------|---------|
| `fix:` | patch | 0.5.0 → 0.5.1 |
| `feat:` | patch | 0.5.0 → 0.5.1 |
| `BREAKING CHANGE:` | minor | 0.5.0 → 0.6.0 |

### Changelog Visibility

Per `.release-please-config.json`, only `feat`, `fix`, `refactor` and `perf` commits appear in release notes. `docs`, `chore`, `test`, `build` and `ci` commits are hidden from the changelog (and do not trigger a version bump).
