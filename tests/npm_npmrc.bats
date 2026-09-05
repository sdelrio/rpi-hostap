#!/usr/bin/env bats

NPMRC="docs-site/.npmrc"

@test "docs-site/.npmrc exists" {
    [ -f "$NPMRC" ]
}

@test "npmrc sets ignore-scripts=true" {
    run grep -q '^ignore-scripts=true' "$NPMRC"
    [ "$status" -eq 0 ]
}

@test "npmrc sets min-release-age=1" {
    run grep -q '^min-release-age=1$' "$NPMRC"
    [ "$status" -eq 0 ]
}

@test "npmrc sets audit=true" {
    run grep -q '^audit=true' "$NPMRC"
    [ "$status" -eq 0 ]
}

@test "npmrc sets fund=false" {
    run grep -q '^fund=false' "$NPMRC"
    [ "$status" -eq 0 ]
}

@test "npm ci completes with scripts blocked" {
    run bash -c 'cd docs-site && npm ci 2>&1'
    [ "$status" -eq 0 ]
    [[ "$output" != *"preinstall"* ]]
    [[ "$output" != *"postinstall"* ]]
}

@test "npm run build still works with ignore-scripts" {
    run bash -c 'cd docs-site && npm run build 2>&1'
    [ "$status" -eq 0 ]
}
