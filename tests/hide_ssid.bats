#!/usr/bin/env bats

# Helper to extract HIDE_SSID logic from wlanstart.sh
# Tests the bash parameter expansion: ${HIDE_SSID+"ssid_hidden=${HIDE_SSID}"}

setup() {
    unset HIDE_SSID
}

compute_ssid_hidden_line() {
    # Replicate the bash expansion from wlanstart.sh
    local result="${HIDE_SSID+"ssid_hidden=${HIDE_SSID}"}"
    echo "${result}"
}

@test "HIDE_SSID not set produces no config line" {
    run compute_ssid_hidden_line
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "HIDE_SSID=1 produces ssid_hidden=1" {
    HIDE_SSID=1
    run compute_ssid_hidden_line
    [ "$status" -eq 0 ]
    [ "$output" = "ssid_hidden=1" ]
}

@test "HIDE_SSID=0 produces ssid_hidden=0" {
    HIDE_SSID=0
    run compute_ssid_hidden_line
    [ "$status" -eq 0 ]
    [ "$output" = "ssid_hidden=0" ]
}

@test "HIDE_SSID empty string produces ssid_hidden with empty value" {
    HIDE_SSID=""
    run compute_ssid_hidden_line
    [ "$status" -eq 0 ]
    [ "$output" = "ssid_hidden=" ]
}
