#!/usr/bin/env bats

setup() {
    . "${BATS_TEST_DIRNAME}/../lib/extra_opts.sh"
    unset HOSTAPD_EXTRA_OPTS
}

@test "HOSTAPD_EXTRA_OPTS unset produces no output" {
    run compute_extra_opts_lines
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "HOSTAPD_EXTRA_OPTS empty string produces no output" {
    HOSTAPD_EXTRA_OPTS=""
    run compute_extra_opts_lines
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "HOSTAPD_EXTRA_OPTS single line is passed through verbatim" {
    HOSTAPD_EXTRA_OPTS="auth_algs=3"
    run compute_extra_opts_lines
    [ "$status" -eq 0 ]
    [ "$output" = "auth_algs=3" ]
}

@test "HOSTAPD_EXTRA_OPTS multiple lines are emitted in order" {
    HOSTAPD_EXTRA_OPTS=$'auth_algs=3\nignore_broadcast_ssid=1\nbeacon_int=100'
    run compute_extra_opts_lines
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "auth_algs=3" ]
    [ "${lines[1]}" = "ignore_broadcast_ssid=1" ]
    [ "${lines[2]}" = "beacon_int=100" ]
}

@test "HOSTAPD_EXTRA_OPTS blank lines are skipped" {
    HOSTAPD_EXTRA_OPTS=$'auth_algs=3\n\n\nbeacon_int=100\n'
    run compute_extra_opts_lines
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "emit_hostapd_conf appends extra opts at end of config" {
    export INTERFACE=wlan0 SSID=test WPA_PASSPHRASE=passw0rd
    export HW_MODE=g CHANNEL=6 WPA_VERSION=2
    export MAX_STATIONS=0
    export HOSTAPD_EXTRA_OPTS=$'auth_algs=3\nbeacon_int=100'
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
    [ "${#lines[@]}" -ge 2 ]
    [ "${lines[${#lines[@]} - 1]}" = "beacon_int=100" ]
    [ "${lines[${#lines[@]} - 2]}" = "auth_algs=3" ]
}

@test "unset HOSTAPD_EXTRA_OPTS leaves config unchanged (no extra trailing lines)" {
    export INTERFACE=wlan0 SSID=test WPA_PASSPHRASE=passw0rd
    export HW_MODE=g CHANNEL=6 WPA_VERSION=2
    export MAX_STATIONS=0
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
    ! grep -q 'auth_algs=' <<< "$output"
}
