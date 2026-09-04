#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONTENT_DIR="$(cd "$(dirname "$0")/.." && pwd)/src/content/docs"

# Clean and recreate content directory
rm -rf "$CONTENT_DIR"
mkdir -p "$CONTENT_DIR"

# Copy docs/ files (rename CI.md -> ci.md for lowercase URLs)
shopt -s nullglob
for f in "$REPO_ROOT"/docs/*.md; do
  name="$(basename "$f")"
  if [ "$name" = "CI.md" ]; then
    name="ci.md"
  fi
  cp "$f" "$CONTENT_DIR/$name"
done
shopt -u nullglob

# Copy root-level markdown files (as .mdx for Starlight)
ROOT_FILES=(README.md SPEC.md CHANGELOG.md)
for src_name in "${ROOT_FILES[@]}"; do
  if [[ ! -f "$REPO_ROOT/$src_name" ]]; then
    echo "Warning: $src_name not found, skipping" >&2
    continue
  fi
  name="${src_name%.md}"
  cp "$REPO_ROOT/$src_name" "$CONTENT_DIR/${name}.mdx"
done

echo "Copied content files to $CONTENT_DIR"
