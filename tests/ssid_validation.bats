#!/usr/bin/env bats

# Tests exercise validate_ssid() from lib/validation.sh - the exact
# code used by wlanstart.sh (no duplicated logic).

load_lib() {
    . "${BATS_TEST_DIRNAME}/../lib/validation.sh"
}

@test "default SSID 'raspberry' is accepted" {
    load_lib
    run validate_ssid "raspberry"
    [ "$status" -eq 0 ]
}

@test "32-character SSID is accepted" {
    load_lib
    run validate_ssid "$(printf 'a%.0s' {1..32})"
    [ "$status" -eq 0 ]
}

@test "empty SSID is rejected" {
    load_lib
    run validate_ssid ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "33-character SSID is rejected with error message" {
    load_lib
    run validate_ssid "$(printf 'a%.0s' {1..33})"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
    [[ "$output" == *"32"* ]]
}

@test "SSID containing newline (config key injection) is rejected" {
    load_lib
    run validate_ssid $'legit\nauth_algs=1'
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID containing '=' (config key injection) is rejected" {
    load_lib
    run validate_ssid "ssid=evil"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID containing '#' (comment injection) is rejected" {
    load_lib
    run validate_ssid "my#ssid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID with leading whitespace is rejected" {
    load_lib
    run validate_ssid " ssid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID with trailing whitespace is rejected" {
    load_lib
    run validate_ssid "ssid "
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}
