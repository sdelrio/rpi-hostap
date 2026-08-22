#!/bin/sh
# Print the project version from the release-please manifest (single source of truth).
set -eu

ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
jq -r '."."' "$ROOT/.release-please-manifest.json"
