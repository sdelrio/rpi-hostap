#!/usr/bin/env bats

# Helper to extract AP_ISOLATION logic from wlanstart.sh
# Tests the bash parameter expansion: ${AP_ISOLATION+"ap_isolate=${AP_ISOLATION}"}

setup() {
    unset AP_ISOLATION
}

compute_ap_isolation_line() {
    # Replicate the bash expansion from wlanstart.sh
    local result="${AP_ISOLATION+"ap_isolate=${AP_ISOLATION}"}"
    echo "${result}"
}

@test "AP_ISOLATION not set produces no config line" {
    run compute_ap_isolation_line
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "AP_ISOLATION=1 produces ap_isolate=1" {
    AP_ISOLATION=1
    run compute_ap_isolation_line
    [ "$status" -eq 0 ]
    [ "$output" = "ap_isolate=1" ]
}

@test "AP_ISOLATION=0 produces ap_isolate=0" {
    AP_ISOLATION=0
    run compute_ap_isolation_line
    [ "$status" -eq 0 ]
    [ "$output" = "ap_isolate=0" ]
}

@test "AP_ISOLATION empty string produces ap_isolate with empty value" {
    AP_ISOLATION=""
    run compute_ap_isolation_line
    [ "$status" -eq 0 ]
    [ "$output" = "ap_isolate=" ]
}
