#!/usr/bin/env bats

# Helper to extract WPA_VERSION config logic from wlanstart.sh

setup() {
    unset WPA_VERSION
    unset HW_MODE
    unset _WPA_CONF
}

compute_wpa_conf() {
    : "${HW_MODE:=g}"
    : "${WPA_VERSION:=2}"
    case "${WPA_VERSION}" in
        2)
            _WPA_LEVEL="wpa=2"
            _WPA_KEY_MGMT="wpa_key_mgmt=WPA-PSK"
            _WPA_PAIRWISE="# TKIP is no secure anymore
#wpa_pairwise=TKIP CCMP
wpa_pairwise=CCMP
rsn_pairwise=CCMP"
            ;;
        3|mixed)
            if [ "${HW_MODE}" = "b" ] ; then
                echo "[Warning] WPA3/SAE with hw_mode=b (802.11b) is unusual; SAE-capable devices expect g/a." >&2
            fi
            _WPA_LEVEL="wpa=3"
            _WPA_PAIRWISE="rsn_pairwise=CCMP"
            if [ "${WPA_VERSION}" = "3" ] ; then
                echo "[Info] WPA3-SAE enabled. Requires client devices with SAE support (wpa_supplicant 2.7+)." >&2
                _WPA_KEY_MGMT="wpa_key_mgmt=SAE"
            else
                echo "[Info] WPA2/WPA3 transition mode enabled. Legacy WPA2 clients allowed alongside SAE." >&2
                _WPA_KEY_MGMT="wpa_key_mgmt=WPA-PSK SAE"
                _WPA_PAIRWISE="wpa_pairwise=CCMP
${_WPA_PAIRWISE}"
            fi
            ;;
        *)
            echo "[Error] Invalid WPA_VERSION '${WPA_VERSION}'. Must be 2 (WPA2-PSK), 3 (WPA3-SAE) or mixed (transition)." >&2
            return 1
            ;;
    esac
    _WPA_CONF="${_WPA_LEVEL}
wpa_passphrase=\${WPA_PASSPHRASE}
${_WPA_KEY_MGMT}
${_WPA_PAIRWISE}"
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

@test "WPA_VERSION=mixed produces wpa=3 with WPA-PSK SAE" {
    WPA_VERSION=mixed
    run compute_wpa_conf
    [ "$status" -eq 0 ]
    [[ "$output" == *"wpa=3"* ]]
    [[ "$output" == *"wpa_key_mgmt=WPA-PSK SAE"* ]]
    [[ "$output" == *"wpa_pairwise=CCMP"* ]]
    [[ "$output" == *"rsn_pairwise=CCMP"* ]]
}

@test "WPA_VERSION=3 with hw_mode=b emits warning" {
    WPA_VERSION=3
    HW_MODE=b
    run compute_wpa_conf
    [ "$status" -eq 0 ]
    [[ "$output" == *"hw_mode=b"* ]]
}

@test "WPA_VERSION=mixed with hw_mode=g does not emit hw_mode warning" {
    WPA_VERSION=mixed
    HW_MODE=g
    run compute_wpa_conf
    [ "$status" -eq 0 ]
    [[ "$output" != *"hw_mode=b"* ]]
}

@test "invalid WPA_VERSION fails with error" {
    WPA_VERSION=1
    run compute_wpa_conf
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_VERSION"* ]]
}
