#!/usr/bin/env bats

# Helper to extract credential warning logic from wlanstart.sh

setup() {
    export INTERFACE="wlan0"
    unset SSID
    unset WPA_PASSPHRASE
}

check_warnings() {
    local warnings=""
    true ${SSID:=raspberry}
    true ${WPA_PASSPHRASE:=passw0rd}
    if [ "${SSID}" = "raspberry" ] ; then
        warnings="${warnings}[Warning] Using default SSID 'raspberry'. Set SSID env var for production.
"
    fi
    if [ "${WPA_PASSPHRASE}" = "passw0rd" ] ; then
        warnings="${warnings}[Warning] Using default WPA passphrase. Set WPA_PASSPHRASE env var for production.
"
    fi
    if [ -n "${warnings}" ] ; then
        printf "%s" "${warnings}"
        return 0
    fi
    return 0
}

@test "default WPA passphrase triggers warning" {
    WPA_PASSPHRASE="passw0rd"
    run check_warnings
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"WPA passphrase"* ]]
}

@test "custom WPA passphrase does not trigger warning" {
    WPA_PASSPHRASE="mysecretpassword"
    run check_warnings
    [ "$status" -eq 0 ]
    [[ "$output" != *"Warning"*"WPA passphrase"* ]]
}

@test "default SSID triggers warning" {
    SSID="raspberry"
    run check_warnings
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"SSID"* ]]
}

@test "custom SSID does not trigger warning" {
    SSID="MyNetwork"
    run check_warnings
    [ "$status" -eq 0 ]
    [[ "$output" != *"Warning"*"SSID"* ]]
}

@test "both defaults trigger both warnings" {
    SSID="raspberry"
    WPA_PASSPHRASE="passw0rd"
    run check_warnings
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"SSID"* ]]
    [[ "$output" == *"Warning"*"WPA passphrase"* ]]
}

@test "both custom values trigger no warnings" {
    SSID="MyNetwork"
    WPA_PASSPHRASE="mysecretpassword"
    run check_warnings
    [ "$status" -eq 0 ]
    [[ "$output" != *"Warning"* ]]
}
