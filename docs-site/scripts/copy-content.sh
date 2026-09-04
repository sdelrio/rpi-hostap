#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCS_DIR="${REPO_ROOT}/docs"
CONTENT_DIR="${SCRIPT_DIR}/../src/content/docs"

mkdir -p "${CONTENT_DIR}"

if [ ! -d "${DOCS_DIR}" ]; then
  echo "Warning: ${DOCS_DIR} does not exist, skipping content copy" >&2
  exit 0
fi

find "${DOCS_DIR}" -name '*.md' -type f | while read -r file; do
  rel_path="${file#"${DOCS_DIR}/"}"
  dest="${CONTENT_DIR}/${rel_path}"
  mkdir -p "$(dirname "${dest}")"
  cp "${file}" "${dest}"
  echo "Copied: ${rel_path}"
done

echo "Content copy complete"