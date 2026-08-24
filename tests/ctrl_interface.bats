#!/usr/bin/env bats

# Tests exercise compute_ctrl_interface_conf() from lib/ctrl_interface.sh —
# the exact code used by wlanstart.sh (no duplicated logic).

setup() {
    unset CTRL_INTERFACE
    unset HEALTHCHECK_DEEP
}

load_lib() {
    . "${BATS_TEST_DIRNAME}/../lib/ctrl_interface.sh"
}

@test "CTRL_INTERFACE not set produces no config line" {
    load_lib
    run compute_ctrl_interface_conf
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CTRL_INTERFACE empty string produces no config line" {
    load_lib
    CTRL_INTERFACE=""
    run compute_ctrl_interface_conf
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CTRL_INTERFACE=1 produces ctrl_interface lines" {
    load_lib
    CTRL_INTERFACE=1
    run compute_ctrl_interface_conf
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "ctrl_interface=/var/run/hostapd" ]
    [ "${lines[1]}" = "ctrl_interface_group=0" ]
}

@test "CTRL_INTERFACE=yes produces ctrl_interface lines" {
    load_lib
    CTRL_INTERFACE=yes
    run compute_ctrl_interface_conf
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "ctrl_interface=/var/run/hostapd" ]
    [ "${lines[1]}" = "ctrl_interface_group=0" ]
}

@test "HEALTHCHECK_DEEP not set produces no config line" {
    load_lib
    run compute_ctrl_interface_conf
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "HEALTHCHECK_DEEP=1 produces ctrl_interface lines (issue #123)" {
    load_lib
    HEALTHCHECK_DEEP=1
    run compute_ctrl_interface_conf
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "ctrl_interface=/var/run/hostapd" ]
    [ "${lines[1]}" = "ctrl_interface_group=0" ]
}

@test "CTRL_INTERFACE unset with HEALTHCHECK_DEEP empty produces no config line" {
    load_lib
    HEALTHCHECK_DEEP=""
    run compute_ctrl_interface_conf
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}
