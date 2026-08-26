#!/usr/bin/env bats

# Tests exercise wpa_compute_conf() from lib/wpa.sh — the exact code
# used by wlanstart.sh (no duplicated logic).

setup() {
    unset WPA_VERSION
    unset HW_MODE
    unset _WPA_CONF
    unset _WPA_LEVEL
    unset _WPA_KEY_MGMT
    unset _WPA_PAIRWISE
    # shellcheck source=../lib/env.sh
    . "${BATS_TEST_DIRNAME}/../lib/env.sh"
    # Defaults now live centrally in lib/env.sh (issue #237)
    env_resolve_config_env
}

load_lib() {
    . "${BATS_TEST_DIRNAME}/../lib/wpa.sh"
}

@test "default WPA_VERSION produces wpa=2 with WPA-PSK" {
    load_lib
    run wpa_compute_conf
    [ "$status" -eq 0 ]
    [[ "$output" == *"wpa=2"* ]]
    [[ "$output" == *"wpa_key_mgmt=WPA-PSK"* ]]
    [[ "$output" != *"SAE"* ]]
}

@test "WPA_VERSION=3 produces wpa=3 with SAE" {
    load_lib
    WPA_VERSION=3
    run wpa_compute_conf
    [ "$status" -eq 0 ]
    [[ "$output" == *"wpa=3"* ]]
    [[ "$output" == *"wpa_key_mgmt=SAE"* ]]
    [[ "$output" == *"ieee80211w=2"* ]]
    [[ "$output" == *"rsn_pairwise=CCMP"* ]]
}

@test "WPA_VERSION=3 does not include WPA-PSK" {
    load_lib
    WPA_VERSION=3
    run wpa_compute_conf
    [ "$status" -eq 0 ]
    [[ "$output" != *"WPA-PSK"* ]]
}

@test "WPA_VERSION=mixed produces wpa=3 with WPA-PSK SAE" {
    load_lib
    WPA_VERSION=mixed
    run wpa_compute_conf
    [ "$status" -eq 0 ]
    [[ "$output" == *"wpa=3"* ]]
    [[ "$output" == *"wpa_key_mgmt=WPA-PSK SAE"* ]]
    [[ "$output" == *"ieee80211w=1"* ]]
    [[ "$output" == *"wpa_pairwise=CCMP"* ]]
    [[ "$output" == *"rsn_pairwise=CCMP"* ]]
}

@test "WPA_VERSION=3 with hw_mode=b emits warning" {
    load_lib
    WPA_VERSION=3
    HW_MODE=b
    run wpa_compute_conf
    [ "$status" -eq 0 ]
    [[ "$output" == *"hw_mode=b"* ]]
}

@test "WPA_VERSION=mixed with hw_mode=g does not emit hw_mode warning" {
    load_lib
    WPA_VERSION=mixed
    HW_MODE=g
    run wpa_compute_conf
    [ "$status" -eq 0 ]
    [[ "$output" != *"hw_mode=b"* ]]
}

@test "WPA_VERSION=2 does not include ieee80211w" {
    load_lib
    WPA_VERSION=2
    run wpa_compute_conf
    [ "$status" -eq 0 ]
    [[ "$output" != *"ieee80211w"* ]]
}

@test "invalid WPA_VERSION fails with error" {
    load_lib
    WPA_VERSION=1
    run wpa_compute_conf
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_VERSION"* ]]
}
