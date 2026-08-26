#!/usr/bin/env bats

# Tests exercise validation_check_ssid() from lib/core/validation.sh - the exact
# code used by wlanstart.sh (no duplicated logic).

load_lib() {
    . "${BATS_TEST_DIRNAME}/../lib/core/validation.sh"
}

@test "default SSID 'raspberry' is accepted" {
    load_lib
    run validation_check_ssid "raspberry"
    [ "$status" -eq 0 ]
}

@test "32-character SSID is accepted" {
    load_lib
    run validation_check_ssid "$(printf 'a%.0s' {1..32})"
    [ "$status" -eq 0 ]
}

@test "empty SSID is rejected" {
    load_lib
    run validation_check_ssid ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "33-character SSID is rejected with error message" {
    load_lib
    run validation_check_ssid "$(printf 'a%.0s' {1..33})"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
    [[ "$output" == *"32"* ]]
}

@test "SSID containing newline (config key injection) is rejected" {
    load_lib
    run validation_check_ssid $'legit\nauth_algs=1'
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID containing '=' (config key injection) is rejected" {
    load_lib
    run validation_check_ssid "ssid=evil"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID containing '#' (comment injection) is rejected" {
    load_lib
    run validation_check_ssid "my#ssid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID with leading whitespace is rejected" {
    load_lib
    run validation_check_ssid " ssid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID with trailing whitespace is rejected" {
    load_lib
    run validation_check_ssid "ssid "
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID of 32 multibyte characters (over 32 bytes) is rejected" {
    load_lib
    run validation_check_ssid "$(printf 'é%.0s' {1..32})"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SSID"* ]]
}

@test "SSID within 32 bytes containing multibyte characters is accepted" {
    load_lib
    run validation_check_ssid "ááááááááááááááá"  # 15 chars = 30 bytes in UTF-8
    [ "$status" -eq 0 ]
}
