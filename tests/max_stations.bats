#!/usr/bin/env bats

# Shared MAX_STATIONS logic from lib/stations.sh

setup() {
    unset MAX_STATIONS
    unset _MAX_STA_CONF
    # shellcheck source=../lib/stations.sh
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/stations.sh"
}

@test "default MAX_STATIONS=0 produces no config line" {
    run compute_max_sta_conf
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "MAX_STATIONS=1 produces max_num_sta=1" {
    MAX_STATIONS=1
    run compute_max_sta_conf
    [ "$status" -eq 0 ]
    [ "$output" = "max_num_sta=1" ]
}

@test "MAX_STATIONS=10 produces max_num_sta=10" {
    MAX_STATIONS=10
    run compute_max_sta_conf
    [ "$status" -eq 0 ]
    [ "$output" = "max_num_sta=10" ]
}

@test "MAX_STATIONS=0 produces no config line" {
    MAX_STATIONS=0
    run compute_max_sta_conf
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "negative MAX_STATIONS fails with error and no config line" {
    MAX_STATIONS=-5
    run compute_max_sta_conf
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid MAX_STATIONS"* ]]
    [[ "$output" != *"max_num_sta"* ]]
}

@test "non-numeric MAX_STATIONS fails with error and no config line" {
    MAX_STATIONS="abc"
    run compute_max_sta_conf
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid MAX_STATIONS"* ]]
    [[ "$output" != *"max_num_sta"* ]]
}

@test "MAX_STATIONS=0 does not produce warning" {
    MAX_STATIONS=0
    run compute_max_sta_conf
    [ "$status" -eq 0 ]
    [[ "$output" != *"Invalid"* ]]
}

@test "MAX_STATIONS=10 does not produce warning" {
    MAX_STATIONS=10
    run compute_max_sta_conf
    [ "$status" -eq 0 ]
    [[ "$output" != *"Invalid"* ]]
}

@test "invalid MAX_STATIONS aborts --validate" {
    run env -i PATH="${PATH}" HOME="${HOME}" INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret MAX_STATIONS=abc "${BATS_TEST_DIRNAME}/../wlanstart.sh" --validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid MAX_STATIONS"* ]]
}
