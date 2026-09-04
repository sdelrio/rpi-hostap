#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONTENT_DIR="$(cd "$(dirname "$0")/.." && pwd)/src/content/docs"

# Clean and recreate content directory
rm -rf "$CONTENT_DIR"
mkdir -p "$CONTENT_DIR"

# Copy docs/ files (rename CI.md -> ci.md for lowercase URLs)
for f in "$REPO_ROOT"/docs/*.md; do
  name="$(basename "$f")"
  if [ "$name" = "CI.md" ]; then
    name="ci.md"
  fi
  cp "$f" "$CONTENT_DIR/$name"
done

# Copy root-level markdown files
cp "$REPO_ROOT/README.md"    "$CONTENT_DIR/readme.mdx"
cp "$REPO_ROOT/SPEC.md"      "$CONTENT_DIR/spec.mdx"
cp "$REPO_ROOT/CHANGELOG.md" "$CONTENT_DIR/changelog.mdx"

echo "Copied content files to $CONTENT_DIR"
