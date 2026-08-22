#!/usr/bin/env bats

# Helper to extract MAX_STATIONS logic from wlanstart.sh

setup() {
    unset MAX_STATIONS
    unset _MAX_STA_CONF
}

compute_max_sta_conf() {
    true ${MAX_STATIONS:=0}
    if [ "${MAX_STATIONS}" != "0" ] && ! [ "${MAX_STATIONS}" -gt 0 ] 2>/dev/null ; then
        echo "[Warning] Invalid MAX_STATIONS '${MAX_STATIONS}'. Must be a non-negative integer. Ignoring."
    fi
    _MAX_STA_CONF=""
    if [ "${MAX_STATIONS}" -gt 0 ] 2>/dev/null ; then
        _MAX_STA_CONF="max_num_sta=${MAX_STATIONS}"
    fi
    echo "${_MAX_STA_CONF}"
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

@test "negative MAX_STATIONS produces warning and no config line" {
    MAX_STATIONS=-5
    run compute_max_sta_conf
    [ "$status" -eq 0 ]
    [[ "$output" == *"Invalid MAX_STATIONS"* ]]
    [[ "$output" != *"max_num_sta"* ]]
}

@test "non-numeric MAX_STATIONS produces warning and no config line" {
    MAX_STATIONS="abc"
    run compute_max_sta_conf
    [ "$status" -eq 0 ]
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
