# CI

## Release Please Version Bumping

With `bump-minor-pre-major: false` and `bump-patch-for-minor-pre-major: false` (pre-1.0):

| Commit type | Version bump | Example |
|-------------|-------------|---------|
| `fix:` | patch | 0.5.0 → 0.5.1 |
| `feat:` | minor | 0.5.0 → 0.6.0 |
| `BREAKING CHANGE:` | major | 0.5.0 → 1.0.0 |
