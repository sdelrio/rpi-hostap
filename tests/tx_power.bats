#!/usr/bin/env bats

# Shared TX_POWER logic from lib/radio.sh

setup() {
    unset TX_POWER
    INTERFACE=wlan0
    COUNTRY_CODE=EU
    # shellcheck source=../lib/env.sh
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/env.sh"
    env_resolve_config_env
    # shellcheck source=../lib/radio.sh
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/radio.sh"
}

@test "unset TX_POWER validates OK" {
    run radio_validate_tx_power
    [ "$status" -eq 0 ]
}

@test "TX_POWER=auto validates OK" {
    TX_POWER=auto
    run radio_validate_tx_power
    [ "$status" -eq 0 ]
}

@test "TX_POWER=20 (dBm) validates OK" {
    TX_POWER=20
    run radio_validate_tx_power
    [ "$status" -eq 0 ]
}

@test "TX_POWER=0 validates OK" {
    TX_POWER=0
    run radio_validate_tx_power
    [ "$status" -eq 0 ]
}

@test "invalid TX_POWER 'high' fails with error" {
    TX_POWER=high
    run radio_validate_tx_power
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid TX_POWER"* ]]
}

@test "negative TX_POWER fails with error" {
    TX_POWER=-5
    run radio_validate_tx_power
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid TX_POWER"* ]]
}

@test "non-numeric TX_POWER with digits mixed in fails" {
    TX_POWER=10dbm
    run radio_validate_tx_power
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid TX_POWER"* ]]
}

@test "radio_apply_tx_power is a no-op when unset" {
    run radio_apply_tx_power
    [ "$status" -eq 0 ]
}

@test "radio_apply_tx_power runs iw set txpower fixed for dBm values" {
    TX_POWER=15
    PATH="/usr/bin:/bin"
    mkdir -p "$BATS_TMPDIR/fakebin"
    printf '#!/bin/sh\necho "iw $@"\n' > "$BATS_TMPDIR/fakebin/iw"
    chmod +x "$BATS_TMPDIR/fakebin/iw"
    PATH="$BATS_TMPDIR/fakebin:$PATH" run radio_apply_tx_power
    rm -rf "$BATS_TMPDIR/fakebin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"iw dev wlan0 set txpower fixed 15"* ]]
}

@test "radio_apply_tx_power runs iw set txpower auto for auto" {
    TX_POWER=auto
    mkdir -p "$BATS_TMPDIR/fakebin"
    printf '#!/bin/sh\necho "iw $@"\n' > "$BATS_TMPDIR/fakebin/iw"
    chmod +x "$BATS_TMPDIR/fakebin/iw"
    PATH="$BATS_TMPDIR/fakebin:$PATH" run radio_apply_tx_power
    rm -rf "$BATS_TMPDIR/fakebin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"iw dev wlan0 set txpower auto"* ]]
}

@test "iw failure makes radio_apply_tx_power fatal" {
    TX_POWER=15
    mkdir -p "$BATS_TMPDIR/fakebin"
    printf '#!/bin/sh\nexit 1\n' > "$BATS_TMPDIR/fakebin/iw"
    chmod +x "$BATS_TMPDIR/fakebin/iw"
    PATH="$BATS_TMPDIR/fakebin:$PATH" run radio_apply_tx_power
    rm -rf "$BATS_TMPDIR/fakebin"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to set txpower"* ]]
}

@test "invalid TX_POWER rejected by --validate before config output" {
    run env -i PATH="${PATH}" HOME="${HOME}" INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret TX_POWER=loud "${BATS_TEST_DIRNAME}/../wlanstart.sh" --validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid TX_POWER"* ]]
    [[ "$output" != *"=== /etc/hostapd.conf ==="* ]]
}

@test "valid TX_POWER accepted by --validate" {
    run env -i PATH="${PATH}" HOME="${HOME}" INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret TX_POWER=20 "${BATS_TEST_DIRNAME}/../wlanstart.sh" --validate
    [ "$status" -eq 0 ]
}
