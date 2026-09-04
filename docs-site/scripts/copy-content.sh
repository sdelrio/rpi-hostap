#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONTENT_DIR="$(cd "$(dirname "$0")/.." && pwd)/src/content/docs"

# Clean and recreate content directory
rm -rf "$CONTENT_DIR"
mkdir -p "$CONTENT_DIR"

# Extract title from first heading in markdown file
extract_title() {
  local file="$1"
  # Get first line starting with # and strip the heading markers and leading/trailing spaces
  grep -m1 '^# ' "$file" | sed 's/^# //' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

# Strip the first heading line (and trailing blank line) from a file.
# Starlight renders the frontmatter title as <h1>, so keeping the
# markdown heading causes a duplicated title on every page.
strip_title_heading() {
  sed '1{/^# /d;}' | sed '1{/^$/d;}'
}

# Copy docs/ files with frontmatter (rename CI.md -> ci.md for lowercase URLs)
shopt -s nullglob
for f in "$REPO_ROOT"/docs/*.md; do
  name="$(basename "$f")"
  if [ "$name" = "CI.md" ]; then
    name="ci.md"
  fi
  title="$(extract_title "$f")"
  {
    echo "---"
    echo "title: \"$title\""
    echo "---"
    echo ""
    cat "$f" | strip_title_heading
  } > "$CONTENT_DIR/$name"
done
shopt -u nullglob

# Copy root-level markdown files
# CHANGELOG.md uses .md extension to avoid MDX parsing issues with shell syntax
ROOT_FILES=(README.md SPEC.md)
for src_name in "${ROOT_FILES[@]}"; do
  if [[ ! -f "$REPO_ROOT/$src_name" ]]; then
    echo "Warning: $src_name not found, skipping" >&2
    continue
  fi
  name="${src_name%.md}"
  title="$(extract_title "$REPO_ROOT/$src_name")"
  {
    echo "---"
    echo "title: \"$title\""
    echo "---"
    echo ""
    cat "$REPO_ROOT/$src_name" | strip_title_heading
  } > "$CONTENT_DIR/${name}.mdx"
done

# Copy CHANGELOG as .md (not .mdx) to avoid MDX parsing issues with shell syntax
if [[ -f "$REPO_ROOT/CHANGELOG.md" ]]; then
  title="$(extract_title "$REPO_ROOT/CHANGELOG.md")"
  {
    echo "---"
    echo "title: \"$title\""
    echo "---"
    echo ""
    cat "$REPO_ROOT/CHANGELOG.md" | strip_title_heading
  } > "$CONTENT_DIR/changelog.md"
fi

echo "Copied content files to $CONTENT_DIR"
