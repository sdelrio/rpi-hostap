#!/usr/bin/env bats

# Helper to extract WPA_VERSION config logic from wlanstart.sh

setup() {
    unset WPA_VERSION
    unset _WPA_CONF
}

compute_wpa_conf() {
    : "${WPA_VERSION:=2}"
    case "${WPA_VERSION}" in
        2)
            _WPA_CONF="wpa=2
wpa_passphrase=\${WPA_PASSPHRASE}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP"
            ;;
        3)
            _WPA_CONF="wpa=3
wpa_passphrase=\${WPA_PASSPHRASE}
wpa_key_mgmt=SAE
rsn_pairwise=CCMP"
            ;;
        *)
            echo "[Error] Invalid WPA_VERSION '${WPA_VERSION}'. Must be 2 (WPA2-PSK) or 3 (WPA3-SAE)." >&2
            return 1
            ;;
    esac
    echo "${_WPA_CONF}"
}

@test "default WPA_VERSION produces wpa=2 with WPA-PSK" {
    run compute_wpa_conf
    [ "$status" -eq 0 ]
    [[ "$output" == *"wpa=2"* ]]
    [[ "$output" == *"wpa_key_mgmt=WPA-PSK"* ]]
    [[ "$output" != *"SAE"* ]]
}

@test "WPA_VERSION=3 produces wpa=3 with SAE" {
    WPA_VERSION=3
    run compute_wpa_conf
    [ "$status" -eq 0 ]
    [[ "$output" == *"wpa=3"* ]]
    [[ "$output" == *"wpa_key_mgmt=SAE"* ]]
    [[ "$output" == *"rsn_pairwise=CCMP"* ]]
}

@test "WPA_VERSION=3 does not include WPA-PSK" {
    WPA_VERSION=3
    run compute_wpa_conf
    [ "$status" -eq 0 ]
    [[ "$output" != *"WPA-PSK"* ]]
}

@test "invalid WPA_VERSION fails with error" {
    WPA_VERSION=1
    run compute_wpa_conf
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_VERSION"* ]]
}
