#!/usr/bin/env bats

# Tests exercise validate_passphrase() from lib/passphrase.sh — the exact
# code used by wlanstart.sh (no duplicated logic).

setup() {
    unset WPA_PASSPHRASE
}

load_lib() {
    . "${BATS_TEST_DIRNAME}/../lib/passphrase.sh"
}

@test "8-character passphrase is accepted" {
    load_lib
    WPA_PASSPHRASE=12345678
    run validate_passphrase
    [ "$status" -eq 0 ]
}

@test "63-character passphrase is accepted" {
    load_lib
    WPA_PASSPHRASE=$(printf 'a%.0s' {1..63})
    run validate_passphrase
    [ "$status" -eq 0 ]
}

@test "7-character passphrase is rejected with error message" {
    load_lib
    WPA_PASSPHRASE=1234567
    run validate_passphrase
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_PASSPHRASE"* ]]
    [[ "$output" == *"8-63"* ]]
}

@test "64-character passphrase is rejected with error message" {
    load_lib
    WPA_PASSPHRASE=$(printf 'a%.0s' {1..64})
    run validate_passphrase
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_PASSPHRASE"* ]]
    [[ "$output" == *"8-63"* ]]
}

@test "empty passphrase is rejected" {
    load_lib
    WPA_PASSPHRASE=""
    run validate_passphrase
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_PASSPHRASE"* ]]
}
