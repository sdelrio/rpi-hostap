#!/bin/sh
# Print the project version as defined by ENV VERSION in the Dockerfile.
set -eu

ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
grep "ENV VERSION" "$ROOT/Dockerfile" | awk -F= '{print $NF}'
