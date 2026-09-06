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
  if [ "$name" = "INDEX.md" ]; then
    name="index.mdx"
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

# Compose README.mdx with Starlight hero, badges, and CardGrid.
# Uses comment markers in README.md to extract sections dynamically:
#   <!-- DOCS_SITE_TAGLINE -->...<!-- /DOCS_SITE_TAGLINE -->
#   <!-- DOCS_SITE_BADGES -->...<!-- /DOCS_SITE_BADGES -->
#   <!-- DOCS_SITE_CARDS -->...<!-- /DOCS_SITE_CARDS -->
extract_between_markers() {
  local file="$1" start_marker="$2" end_marker="$3"
  sed -n "/$start_marker/,/$end_marker/{
    /$start_marker/d; /$end_marker/d; p
  }" "$file" | sed '/^[[:space:]]*$/d' | sed 's/^[[:space:]]*//'
}

# Strip all HTML comments (lines containing only <!-- ... -->)
strip_html_comments() {
  sed '/^[[:space:]]*<!--.*-->[[:space:]]*$/d'
}

if [[ -f "$REPO_ROOT/README.md" ]]; then
  tagline="$(extract_between_markers "$REPO_ROOT/README.md" 'DOCS_SITE_TAGLINE' 'DOCS_SITE_TAGLINE')"

  # Body = everything after title heading, minus badges/tagline/cards marker blocks,
  # with HTML comments stripped.
  body="$(
    sed '1{/^# /d;}' "$REPO_ROOT/README.md" |
    sed '1{/^$/d;}' |
    sed '/<!-- DOCS_SITE_BADGES -->/,/<!-- \/DOCS_SITE_BADGES -->/d' |
    sed '/<!-- DOCS_SITE_TAGLINE -->/,/<!-- \/DOCS_SITE_TAGLINE -->/d' |
    sed '/<!-- DOCS_SITE_CARDS -->/,/<!-- \/DOCS_SITE_CARDS -->/d' |
    strip_html_comments
  )"

  {
    echo "---"
    echo "title: \"rpi-hostap\""
    echo "hero:"
    echo "  title: \"rpi-hostap\""
    echo "  tagline: \"$tagline\""
    echo "  image:"
    echo "    file: ../../assets/logo.svg"
    echo "  actions:"
    echo "    - text: Get Started"
    echo "      link: /rpi-hostap/readme/#quick-start"
    echo "      icon: right-arrow"
    echo "      variant: primary"
    echo "---"
    echo ""
    echo "import { Card, CardGrid } from '@astrojs/starlight/components';"
    echo ""
    echo "$body"
    echo ""
    echo "<CardGrid>"
    echo "  <Card title=\"Configuration\" icon=\"pencil\">"
    echo "    Environment variables, WiFi settings, WPA3/SAE, MAC filtering, and advanced hostapd options."
    echo "  </Card>"
    echo "  <Card title=\"Networking\" icon=\"server\">"
    echo "    NAT/IP forwarding, IPv6 support, and outgoing interface configuration."
    echo "  </Card>"
    echo "  <Card title=\"Operations\" icon=\"laptop\">"
    echo "    Client inspection, runtime management, and day-to-day operational tasks."
    echo "  </Card>"
    echo "</CardGrid>"
  } > "$CONTENT_DIR/readme.mdx"
fi

# Copy SPEC.md
if [[ -f "$REPO_ROOT/SPEC.md" ]]; then
  title="$(extract_title "$REPO_ROOT/SPEC.md")"
  {
    echo "---"
    echo "title: \"$title\""
    echo "---"
    echo ""
    cat "$REPO_ROOT/SPEC.md" | strip_title_heading
  } > "$CONTENT_DIR/spec.mdx"
fi

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
