#!/usr/bin/env bats

# Tests for healthcheck.sh

setup() {
    export INTERFACE="wlan0"
    export HEALTHCHECK_START_PERIOD=15
    export HEALTHCHECK_UPTIME_FILE=$(mktemp)
    echo "100.00 100.00" > "$HEALTHCHECK_UPTIME_FILE"
}

teardown() {
    rm -f "$HEALTHCHECK_UPTIME_FILE"
    rm -rf "$BATS_TEST_TMPDIR/bin"
}

mock_bin() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/$1" <<EOF
#!/bin/bash
$2
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/$1"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "healthcheck script is executable" {
    [ -x "healthcheck.sh" ]
}

@test "healthcheck returns 0 during start period" {
    echo "10.00 10.00" > "$HEALTHCHECK_UPTIME_FILE"
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "healthcheck fails when hostapd is not running" {
    mock_bin pidof 'if [ "$1" = "hostapd" ]; then exit 1; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"hostapd is not running"* ]]
}

@test "healthcheck fails when dnsmasq is not running" {
    mock_bin pidof 'if [ "$1" = "dnsmasq" ]; then exit 1; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"dnsmasq is not running"* ]]
}

@test "healthcheck fails when interface is down" {
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ] && [ "$2" = "show" ]; then exit 1; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"interface wlan0 is not up"* ]]
}

@test "healthcheck succeeds when all checks pass" {
    mock_bin pidof 'exit 0'
    mock_bin ip 'exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "healthcheck fails when AP_ADDR is not assigned to interface" {
    export AP_ADDR="192.168.254.1"
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "-4" ]; then echo "no match"; exit 0; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"192.168.254.1 is not assigned to interface wlan0"* ]]
}

@test "healthcheck passes when AP_ADDR is assigned to interface" {
    export AP_ADDR="192.168.254.1"
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "-4" ]; then echo "inet 192.168.254.1/24"; exit 0; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "healthcheck skips AP_ADDR check when unset" {
    unset AP_ADDR
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "-4" ]; then exit 1; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "healthcheck respects HEALTHCHECK_START_PERIOD env var" {
    export HEALTHCHECK_START_PERIOD=30
    echo "20.00 20.00" > "$HEALTHCHECK_UPTIME_FILE"
    mock_bin pidof 'exit 1'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}
