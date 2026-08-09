# CI

## Release Please Version Bumping

### `bump-minor-pre-major: false` / `bump-patch-for-minor-pre-major: false` (current)

| Commit type | Version bump | Example |
|-------------|-------------|---------|
| `fix:` | patch | 0.5.0 → 0.5.1 |
| `feat:` | minor | 0.5.0 → 0.6.0 |
| `BREAKING CHANGE:` | major | 0.5.0 → 1.0.0 |

### `bump-minor-pre-major: true` / `bump-patch-for-minor-pre-major: true`

| Commit type | Version bump | Example |
|-------------|-------------|---------|
| `fix:` | patch | 0.5.0 → 0.5.1 |
| `feat:` | patch | 0.5.0 → 0.5.1 |
| `BREAKING CHANGE:` | minor | 0.5.0 → 0.6.0 |
