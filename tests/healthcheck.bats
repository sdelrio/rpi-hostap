#!/usr/bin/env bats

# Tests for healthcheck.sh

setup() {
    export INTERFACE="wlan0"
    export HEALTHCHECK_START_PERIOD=15
    # Fake clock and start-time state file (see issue #111)
    export NOW_STAMP=1000
    export HEALTHCHECK_STARTED_FILE=$(mktemp)
    echo "$((NOW_STAMP - 100))" > "$HEALTHCHECK_STARTED_FILE"
    mock_bin date 'echo "$NOW_STAMP"'
}

teardown() {
    rm -f "$HEALTHCHECK_STARTED_FILE"
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

@test "healthcheck returns 0 during start period even with dead daemons" {
    export NOW_STAMP=1000
    echo "$((NOW_STAMP - 5))" > "$HEALTHCHECK_STARTED_FILE"
    mock_bin pidof 'exit 1'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "healthcheck passes when start-time file is missing (defaults to now)" {
    rm -f "$HEALTHCHECK_STARTED_FILE"
    mock_bin pidof 'exit 1'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "healthcheck respects HEALTHCHECK_START_PERIOD env var" {
    export HEALTHCHECK_START_PERIOD=200
    echo "$((NOW_STAMP - 100))" > "$HEALTHCHECK_STARTED_FILE"
    mock_bin pidof 'exit 1'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "invalid HEALTHCHECK_START_PERIOD falls back to 15 with warning" {
    export HEALTHCHECK_START_PERIOD="abc"
    echo "$((NOW_STAMP - 10))" > "$HEALTHCHECK_STARTED_FILE"
    mock_bin pidof 'exit 1'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Warning] Invalid HEALTHCHECK_START_PERIOD 'abc', using 15"* ]]
}

@test "negative HEALTHCHECK_START_PERIOD falls back to 15 with warning" {
    export HEALTHCHECK_START_PERIOD="-5"
    echo "$((NOW_STAMP - 10))" > "$HEALTHCHECK_STARTED_FILE"
    mock_bin pidof 'exit 1'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Warning] Invalid HEALTHCHECK_START_PERIOD '-5', using 15"* ]]
}

@test "empty HEALTHCHECK_START_PERIOD falls back to 15 with warning" {
    export HEALTHCHECK_START_PERIOD=""
    echo "$((NOW_STAMP - 10))" > "$HEALTHCHECK_STARTED_FILE"
    mock_bin pidof 'exit 1'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Warning] Invalid HEALTHCHECK_START_PERIOD '', using 15"* ]]
}

@test "grace period works regardless of host uptime (issue #111)" {
    # Simulate a long-running host: even with huge host uptime, the check
    # must use the recorded start time, not /proc/uptime.
    export NOW_STAMP=$((365 * 24 * 3600))
    echo "$((NOW_STAMP - 1))" > "$HEALTHCHECK_STARTED_FILE"
    mock_bin pidof 'exit 1'
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

@test "healthcheck fails when interface is missing" {
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ] && [ "$2" = "show" ]; then exit 1; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"interface wlan0 is not up"* ]]
}

@test "healthcheck fails when interface exists but is down" {
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "2: wlan0: <BROADCAST,MULTICAST> mtu 1500 state DOWN"; exit 0; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"interface wlan0 is not up"* ]]
}

@test "healthcheck succeeds when interface state is UP" {
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "2: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP"; exit 0; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "healthcheck succeeds when all checks pass" {
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "-4" ]; then echo "inet 192.168.254.1/24"; elif [ "$1" = "link" ]; then echo "state UP"; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "healthcheck fails when AP_ADDR is not assigned to interface" {
    export AP_ADDR="192.168.254.1"
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "state UP"; elif [ "$1" = "-4" ]; then echo "no match"; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"192.168.254.1 is not assigned to interface wlan0"* ]]
}

@test "healthcheck fails when only a same-prefix address is assigned (anchored match)" {
    export AP_ADDR="192.168.254.1"
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "state UP"; elif [ "$1" = "-4" ]; then echo "inet 192.168.254.100/24"; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"192.168.254.1 is not assigned to interface wlan0"* ]]
}

@test "healthcheck passes when AP_ADDR is assigned to interface" {
    export AP_ADDR="192.168.254.1"
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "state UP"; elif [ "$1" = "-4" ]; then echo "inet 192.168.254.1/24"; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "AP_ADDR matches exactly when other same-subnet addresses are also assigned" {
    export AP_ADDR="192.168.254.1"
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "state UP"; elif [ "$1" = "-4" ]; then echo "inet 192.168.254.100/24"; echo "inet 192.168.254.1/24"; echo "inet 192.168.254.11/24"; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "AP_ADDR check does not match when address appears without inet prefix (e.g. in MAC)" {
    export AP_ADDR="192.168.254.1"
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "state UP"; elif [ "$1" = "-4" ]; then echo "inet 10.0.0.1/8"; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
}

@test "healthcheck skips AP_ADDR check when unset" {
    unset AP_ADDR
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "state UP"; elif [ "$1" = "-4" ]; then exit 1; fi; exit 0'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "wlanstart records container start time before daemons launch (issue #111)" {
    local line_started line_multirun
    line_started=$(grep -n 'hostap-started' wlanstart.sh | head -1 | cut -d: -f1)
    line_multirun=$(grep -n '^multirun ' wlanstart.sh | head -1 | cut -d: -f1)
    [ -n "$line_started" ] && [ -n "$line_multirun" ]
    [ "$line_started" -lt "$line_multirun" ]
}

@test "grace period expires and checks are enforced afterwards" {
    export NOW_STAMP=1000
    echo "$((NOW_STAMP - 15))" > "$HEALTHCHECK_STARTED_FILE"
    mock_bin pidof 'exit 1'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"hostapd is not running"* ]]
}

@test "deep check passes when hostapd state is ENABLED (issue #123)" {
    export HEALTHCHECK_DEEP=1
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "state UP"; fi; exit 0'
    mock_bin hostapd_cli 'echo "state=ENABLED"; echo "ssid=raspberry"'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "deep check fails when hostapd is not in ENABLED state (issue #123)" {
    export HEALTHCHECK_DEEP=1
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "state UP"; fi; exit 0'
    mock_bin hostapd_cli 'echo "state=DFS"'
    run ./healthcheck.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"hostapd is not in ENABLED state"* ]]
}

@test "deep check is skipped by default (no HEALTHCHECK_DEEP)" {
    mock_bin pidof 'exit 0'
    mock_bin ip 'if [ "$1" = "link" ]; then echo "state UP"; fi; exit 0'
    mock_bin hostapd_cli 'exit 1'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}

@test "deep check respects start period (grace before DFS CAC finishes)" {
    export HEALTHCHECK_DEEP=1
    export NOW_STAMP=1000
    echo "$((NOW_STAMP - 10))" > "$HEALTHCHECK_STARTED_FILE"
    export HEALTHCHECK_START_PERIOD=90
    mock_bin hostapd_cli 'echo "state=DFS"'
    run ./healthcheck.sh
    [ "$status" -eq 0 ]
}
