#!/usr/bin/env bats

NPMRC="docs-site/.npmrc"

@test "docs-site/.npmrc exists" {
    [ -f "$NPMRC" ]
}

@test "npmrc sets ignore-scripts=true" {
    run grep -q '^ignore-scripts=true' "$NPMRC"
    [ "$status" -eq 0 ]
}

@test "npmrc sets minimum-release-age=1440" {
    run grep -q '^minimum-release-age=1440' "$NPMRC"
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
