#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TIMEOUT=15
RETRIES=3
EXCLUDE_PATTERN='(github\.com/sdelrio/rpi-hostap/(issues|pull|discussions|actions)/)'

md_files=()
while IFS= read -r -d '' f; do
    md_files+=("$f")
done < <(find "$REPO_ROOT" -name '*.md' \
    -not -path '*/node_modules/*' \
    -not -path '*/.astro/*' \
    -not -path '*/dist/*' \
    -not -path '*/.git/*' \
    -not -path '*/tmp/*' \
    -not -path '*/docs-site/src/*' \
    -print0 | sort -z)

fail=0
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
external_urls_file="$tmpdir/external_urls.txt"
external_src_file="$tmpdir/external_sources.txt"
touch "$external_urls_file" "$external_src_file"

check_relative_link() {
    local src_file="$1"
    local link="$2"
    local src_dir
    src_dir="$(dirname "$src_file")"
    local rel_src="${src_file#"$REPO_ROOT"/}"

    local url="$link"
    local anchor=""
    if [[ "$url" == *"#"* ]]; then
        anchor="${url#*#}"
        url="${url%%#*}"
    fi

    if [[ -z "$url" ]]; then
        return 0
    fi

    local target
    target="$(cd "$src_dir" && python3 -c "import os; print(os.path.normpath(os.path.join(os.getcwd(), '$url')))" 2>/dev/null || echo "$src_dir/$url")"

    if [[ ! -e "$target" ]]; then
        echo "  BROKEN: [$rel_src] -> $url (file not found)"
        return 1
    fi

    if [[ -n "$anchor" && "$target" == *.md && -f "$target" ]]; then
        local heading
        heading=$(echo "$anchor" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g; s/[^a-z0-9_-]//g')
        local target_headings
        target_headings=$(/usr/bin/grep -E '^#{1,6} ' "$target" 2>/dev/null | \
            sed 's/^#* *//; s/[`*_]//g' | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g; s/[^a-z0-9_-]//g' || true)
        if ! echo "$target_headings" | /usr/bin/grep -qF "$heading" 2>/dev/null; then
            if ! /usr/bin/grep -qiE "\{#${heading}\}" "$target" 2>/dev/null; then
                local rel_target="${target#"$REPO_ROOT"/}"
                echo "  WARNING: [$rel_src] -> #$anchor (anchor may not exist in $rel_target)"
            fi
        fi
    fi

    return 0
}

check_external_url() {
    local url="$1"
    local attempt=0

    while (( attempt < RETRIES )); do
        local http_code
        http_code=$(curl -sS -o /dev/null -w '%{http_code}' \
            --max-time "$TIMEOUT" --connect-timeout 10 \
            -L -A "markdown-link-check/1.0" \
            "$url" 2>/dev/null) || true

        if [[ "$http_code" =~ ^[23] ]]; then
            return 0
        fi

        attempt=$((attempt + 1))
        if (( attempt < RETRIES )); then
            sleep 1
        fi
    done

    return 1
}

echo "Checking links in ${#md_files[@]} markdown files..."
echo

for md_file in "${md_files[@]}"; do
    rel_file="${md_file#"$REPO_ROOT"/}"

    while IFS= read -r link; do
        [[ -z "$link" ]] && continue

        if [[ "$link" =~ ^https?:// ]]; then
            if [[ "$link" =~ $EXCLUDE_PATTERN ]]; then
                continue
            fi
            if ! /usr/bin/grep -qF "$link" "$external_urls_file" 2>/dev/null; then
                echo "$link" >> "$external_urls_file"
                echo "$rel_file" >> "$external_src_file"
            fi
        else
            if ! check_relative_link "$md_file" "$link"; then
                fail=1
            fi
        fi
    done < <(/usr/bin/grep -oE '\[[^]]*\]\([^)]+\)' "$md_file" 2>/dev/null | \
        sed 's/^\[.*\](\(.*\))$/\1/' || true)
done

url_count=0
if [[ -s "$external_urls_file" ]]; then
    url_count=$(wc -l < "$external_urls_file" | tr -d ' ')
fi

echo "Checking $url_count external URLs..."
echo

if [[ -s "$external_urls_file" ]]; then
    while IFS= read -r url; do
        printf "  %s ... " "$url"
        if check_external_url "$url"; then
            echo "OK"
        else
            echo "BROKEN"
            line_num=$(/usr/bin/grep -nF "$url" "$external_urls_file" | head -1 | cut -d: -f1)
            first_source=$(sed -n "${line_num}p" "$external_src_file")
            echo "    referenced from: $first_source"
            fail=1
        fi
    done < "$external_urls_file"
fi

echo
if [[ "$fail" -ne 0 ]]; then
    echo "Link check FAILED" >&2
    exit 1
fi
echo "Link check: OK ($url_count external URLs checked)"
