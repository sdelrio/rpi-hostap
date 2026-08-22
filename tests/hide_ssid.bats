#!/usr/bin/env bats

setup() {
    . "${BATS_TEST_DIRNAME}/../lib/ssid_hidden.sh"
    unset HIDE_SSID
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
