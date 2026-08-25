#!/usr/bin/env bats

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
    unset HW_MODE
    unset CHANNEL
    unset COUNTRY_CODE
    # shellcheck source=../lib/channel.sh
    . "${ROOT}/lib/channel.sh"
}

# --- g/b mode (2.4 GHz) ---

@test "default values pass validation" {
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=g with channel 1 passes" {
    HW_MODE="g"
    CHANNEL="1"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=g with channel 13 passes (EU default)" {
    HW_MODE="g"
    CHANNEL="13"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=g with channel 14 fails (EU default)" {
    HW_MODE="g"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"Channel 14 is only allowed in Japan"* ]]
}

@test "hw_mode=g with channel 36 fails" {
    HW_MODE="g"
    CHANNEL="36"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"not allowed"* ]]
}

@test "hw_mode=b with channel 1 passes" {
    HW_MODE="b"
    CHANNEL="1"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=b with channel 13 passes (EU default)" {
    HW_MODE="b"
    CHANNEL="13"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=b with channel 14 fails (EU default)" {
    HW_MODE="b"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"Channel 14 is only allowed in Japan"* ]]
}

# --- a mode (5 GHz) ---

@test "hw_mode=a with all non-DFS channels passes" {
    HW_MODE="a"
    for ch in 36 40 44 48 149 153 157 161 165; do
        CHANNEL="${ch}"
        run validate_channel
        [ "$status" -eq 0 ]
    done
}

@test "hw_mode=a with DFS channel 52 warns but passes" {
    HW_MODE="a"
    CHANNEL="52"
    run validate_channel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"DFS"* ]]
}

@test "hw_mode=a with DFS channel 100 warns but passes" {
    HW_MODE="a"
    CHANNEL="100"
    run validate_channel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"DFS"* ]]
}

@test "hw_mode=a with DFS channel 144 warns but passes" {
    HW_MODE="a"
    CHANNEL="144"
    run validate_channel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"DFS"* ]]
}

@test "hw_mode=a with invalid channel fails with clear error" {
    HW_MODE="a"
    for ch in 15 34 50 145 1650; do
        CHANNEL="${ch}"
        run validate_channel
        [ "$status" -eq 1 ]
        [[ "$output" == *"Error"*"not allowed for hw_mode=a"* ]]
    done
}

@test "hw_mode=a rejects channel 11 (2.4 GHz only)" {
    HW_MODE="a"
    CHANNEL="11"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"not allowed for hw_mode=a"* ]]
}

@test "hw_mode=a rejects channel 1 (2.4 GHz only)" {
    HW_MODE="a"
    CHANNEL="1"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"not allowed for hw_mode=a"* ]]
}

# --- ACS (automatic channel selection) ---

@test "CHANNEL=acs passes with hw_mode=g and warns" {
    HW_MODE="g"
    CHANNEL="acs"
    run validate_channel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"acs"* ]]
}

@test "CHANNEL=acs passes with hw_mode=a and warns" {
    HW_MODE="a"
    CHANNEL="acs"
    run validate_channel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"HEALTHCHECK_START_PERIOD"* ]]
}

@test "CHANNEL=ACS (uppercase, case-insensitive) passes with any HW_MODE" {
    for hw in b g a; do
        HW_MODE="${hw}"
        CHANNEL="ACS"
        run validate_channel
        [ "$status" -eq 0 ]
        [[ "$output" == *"Warning"*"acs"* ]]
    done
}

@test "CHANNEL=acs passes strict validation" {
    HW_MODE="g"
    CHANNEL="acs"
    run validate_channel_strict
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"acs"* ]]
}

@test "CHANNEL=Acs and CHANNEL=aCS (mixed case) pass validation" {
    for value in Acs aCS AcS; do
        HW_MODE="g"
        CHANNEL="${value}"
        run validate_channel
        [ "$status" -eq 0 ]
        [[ "$output" == *"Warning"*"acs"* ]]
    done
}

@test "emit_hostapd_conf emits channel=acs unchanged" {
    export INTERFACE=wlan0 SSID=test WPA_PASSPHRASE=passw0rd
    export HW_MODE=g CHANNEL=acs COUNTRY_CODE=EU WPA_VERSION=2
    eval "$(sed -n '/^emit_hostapd_conf()/,/^}/p' "${BATS_TEST_DIRNAME}/../wlanstart.sh")"
    . "${BATS_TEST_DIRNAME}/../lib/stations.sh"
    . "${BATS_TEST_DIRNAME}/../lib/ctrl_interface.sh"
    . "${BATS_TEST_DIRNAME}/../lib/wpa.sh"
    . "${BATS_TEST_DIRNAME}/../lib/ssid_hidden.sh"
    . "${BATS_TEST_DIRNAME}/../lib/mac_filter.sh"
    . "${BATS_TEST_DIRNAME}/../lib/ap_isolation.sh"
    . "${BATS_TEST_DIRNAME}/../lib/extra_opts.sh"
    run emit_hostapd_conf
    [ "$status" -eq 0 ]
    grep -qx 'channel=acs' <<< "$output"
}

# --- non-numeric channel ---

@test "non-numeric channel with hw_mode=g fails" {
    HW_MODE="g"
    CHANNEL="foo"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"positive integer"* ]]
}

@test "non-numeric channel with hw_mode=a fails" {
    HW_MODE="a"
    CHANNEL="bar"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"positive integer"* ]]
}

@test "non-numeric channel with hw_mode=b fails" {
    HW_MODE="b"
    CHANNEL="baz"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"positive integer"* ]]
}

# --- unknown hw_mode ---

@test "unknown hw_mode issues warning and passes" {
    HW_MODE="x"
    CHANNEL="1"
    run validate_channel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"Unknown hw_mode"* ]]
}

# --- country/regulatory domain validation ---

@test "US allows channel 11 but rejects 12" {
    COUNTRY_CODE="US"
    HW_MODE="g"
    CHANNEL="11"
    run validate_channel
    [ "$status" -eq 0 ]
    CHANNEL="12"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"not allowed for country US"* ]]
}

@test "CA rejects channel 12" {
    COUNTRY_CODE="CA"
    HW_MODE="g"
    CHANNEL="12"
    run validate_channel
    [ "$status" -eq 1 ]
}

@test "MX rejects channel 13" {
    COUNTRY_CODE="MX"
    HW_MODE="b"
    CHANNEL="13"
    run validate_channel
    [ "$status" -eq 1 ]
}

@test "EU allows channels 1-13 but rejects 14" {
    COUNTRY_CODE="EU"
    HW_MODE="g"
    for ch in 1 6 11 13; do
        CHANNEL="${ch}"
        run validate_channel
        [ "$status" -eq 0 ]
    done
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Channel 14 is only allowed in Japan"* ]]
}

@test "UK/ES/DE treated as Europe (max 13)" {
    for cc in UK ES DE; do
        COUNTRY_CODE="${cc}"
        HW_MODE="g"
        CHANNEL="13"
        run validate_channel
        [ "$status" -eq 0 ]
        CHANNEL="14"
        run validate_channel
        [ "$status" -eq 1 ]
    done
}

@test "JP + hw_mode=b allows channels 1-14" {
    COUNTRY_CODE="JP"
    HW_MODE="b"
    for ch in 1 6 12 13 14; do
        CHANNEL="${ch}"
        run validate_channel
        [ "$status" -eq 0 ]
    done
}

@test "JP + hw_mode=b + channel 14 passes (802.11b Japan exception)" {
    COUNTRY_CODE="JP"
    HW_MODE="b"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 0 ]
    run validate_channel_strict
    [ "$status" -eq 0 ]
}

@test "unknown country falls back to EU limits (max 13)" {
    COUNTRY_CODE="ZZ"
    HW_MODE="g"
    CHANNEL="13"
    run validate_channel
    [ "$status" -eq 0 ]
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
}

@test "default region is EU (channel 14 rejected without COUNTRY_CODE)" {
    HW_MODE="g"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
}

@test "JP + hw_mode=g + channel 14 rejected with clear message" {
    COUNTRY_CODE="JP"
    HW_MODE="g"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Channel 14 is only allowed in Japan (COUNTRY_CODE=JP) with hw_mode=b (802.11b)"* ]]
    run validate_channel_strict
    [ "$status" -eq 1 ]
}

@test "JP + unknown hw_mode + channel 14 rejected" {
    COUNTRY_CODE="JP"
    HW_MODE="n"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
}

@test "non-JP + hw_mode=b + channel 14 still rejected" {
    COUNTRY_CODE="US"
    HW_MODE="b"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Channel 14 is only allowed in Japan"* ]]
}

@test "acs channel still passes regardless of country/hw_mode" {
    for pair in "JP b" "EU g" "US a"; do
        set -- ${pair}
        COUNTRY_CODE="$1"
        HW_MODE="$2"
        unset CHANNEL
        CHANNEL="acs"
        run validate_channel
        [ "$status" -eq 0 ]
        CHANNEL="ACS"
        run validate_channel
        [ "$status" -eq 0 ]
    done
}

# --- strict validation mode (unknown hw_mode is an error) ---

@test "strict: unknown hw_mode fails with error" {
    HW_MODE="gn"
    CHANNEL="1"
    run validate_channel_strict
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"Unknown hw_mode='gn'"* ]]
}

@test "strict: valid hw_modes pass" {
    for pair in "a 36" "b 1" "g 6"; do
        set -- ${pair}
        HW_MODE="$1"
        CHANNEL="$2"
        run validate_channel_strict
        [ "$status" -eq 0 ]
    done
}

@test "strict: default hw_mode (g) passes" {
    unset HW_MODE
    CHANNEL="1"
    run validate_channel_strict
    [ "$status" -eq 0 ]
}

@test "strict: channel errors still fail" {
    HW_MODE="g"
    CHANNEL="14"
    run validate_channel_strict
    [ "$status" -eq 1 ]
}
