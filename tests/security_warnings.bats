# Shared credential warning logic from lib/core/warnings.sh

setup() {
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/core/warnings.sh"
    export INTERFACE="wlan0"
    unset SSID
    unset WPA_PASSPHRASE
}

check_warnings() {
    : "${SSID:=raspberry}"
    : "${WPA_PASSPHRASE:=passw0rd}"
    warnings_emit_credential_warnings
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
