#!/usr/bin/env bats

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
}

@test "Dockerfile VERSION matches release-please manifest" {
    dockerfile_version=$("$ROOT/scripts/get-version.sh")
    manifest_version=$(jq -r '."."' "$ROOT/.release-please-manifest.json")
    [ -n "$dockerfile_version" ]
    [ -n "$manifest_version" ]
    [ "$dockerfile_version" = "$manifest_version" ]
}

@test "release-please config updates Dockerfile via extra-files" {
    run jq -e '.packages["."]["extra-files"][]? | select(.path == "Dockerfile" and .type == "generic")' "$ROOT/.release-please-config.json"
    [ "$status" -eq 0 ]
}
