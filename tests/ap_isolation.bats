#!/usr/bin/env bats

# Tests exercise compute_ap_isolation_line() from lib/ap_isolation.sh —
# the exact code used by wlanstart.sh (no duplicated logic).

setup() {
    unset AP_ISOLATION
}

load_lib() {
    . "${BATS_TEST_DIRNAME}/../lib/ap_isolation.sh"
}

@test "AP_ISOLATION not set produces no config line" {
    load_lib
    run compute_ap_isolation_line
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "AP_ISOLATION=1 produces ap_isolate=1" {
    load_lib
    AP_ISOLATION=1
    run compute_ap_isolation_line
    [ "$status" -eq 0 ]
    [ "$output" = "ap_isolate=1" ]
}

@test "AP_ISOLATION=0 produces ap_isolate=0" {
    load_lib
    AP_ISOLATION=0
    run compute_ap_isolation_line
    [ "$status" -eq 0 ]
    [ "$output" = "ap_isolate=0" ]
}

@test "AP_ISOLATION empty string produces ap_isolate with empty value" {
    load_lib
    AP_ISOLATION=""
    run compute_ap_isolation_line
    [ "$status" -eq 0 ]
    [ "$output" = "ap_isolate=" ]
}
