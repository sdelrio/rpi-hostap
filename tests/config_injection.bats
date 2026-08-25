#!/usr/bin/env bats

# Tests for config injection guards (issue #184): WPA_PASSPHRASE with
# embedded newlines/control characters, and non-IPv4 PRI_DNS/SEC_DNS.

SCRIPT="${BATS_TEST_DIRNAME}/../wlanstart.sh"

run_validate() {
    env -i PATH="${PATH}" HOME="${HOME}" "$@" "${SCRIPT}" --validate
}

load_passphrase_lib() {
    . "${BATS_TEST_DIRNAME}/../lib/passphrase.sh"
}

@test "passphrase with embedded newline is rejected (startup validator)" {
    load_passphrase_lib
    WPA_PASSPHRASE=$(printf 'goodpass\nwpa_pairwise=NONE')
    run validate_passphrase
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_PASSPHRASE"* ]]
    [[ "$output" == *"must not contain newlines"* ]]
}

@test "passphrase with carriage return is rejected (startup validator)" {
    load_passphrase_lib
    WPA_PASSPHRASE=$(printf 'goodpass\raaa')
    run validate_passphrase
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_PASSPHRASE"* ]]
}

@test "passphrase with control character is rejected (startup validator)" {
    load_passphrase_lib
    WPA_PASSPHRASE=$(printf 'goodpass\tabc')
    run validate_passphrase
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_PASSPHRASE"* ]]
}

@test "--validate rejects passphrase with embedded newline" {
    run run_validate INTERFACE=wlan0 SSID=x "WPA_PASSPHRASE=$(printf 'goodpass\nwpa_pairwise=NONE')"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_PASSPHRASE"* ]]
    [[ "$output" != *"wpa_pairwise=NONE"* ]]
}

@test "--validate rejects non-IPv4 PRI_DNS" {
    run run_validate INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret PRI_DNS="8.8.8.8 dhcp-option=option:router,0.0.0.0"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid PRI_DNS"* ]]
}

@test "--validate rejects non-IPv4 SEC_DNS" {
    run run_validate INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret SEC_DNS="not-an-ip"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SEC_DNS"* ]]
}
