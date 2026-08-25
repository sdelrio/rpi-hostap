#!/usr/bin/env bats

# Tests exercise clients.sh directly with a stubbed hostapd_cli.

setup() {
    unset INTERFACE
    unset CTRL_IFACE_DIR
    export PATH="${BATS_TEST_TMPDIR}:${PATH}"
    cat > "${BATS_TEST_TMPDIR}/hostapd_cli" <<'EOF'
#!/bin/bash
echo "stub hostapd_cli: $*"
EOF
    chmod +x "${BATS_TEST_TMPDIR}/hostapd_cli"
}

@test "missing socket dir prints actionable error and exits non-zero (issue #161)" {
    export INTERFACE=wlan0
    run "${BATS_TEST_DIRNAME}/../clients.sh"
    [ "$status" -ne 0 ]
    [ "${lines[0]}" = "[Error] Control interface not available at /var/run/hostapd." ]
    [ "${lines[1]}" = "Restart the container with -e CTRL_INTERFACE=1 to enable it." ]
}

@test "missing custom CTRL_IFACE_DIR dir reports the configured path" {
    export INTERFACE=wlan0
    export CTRL_IFACE_DIR=/nonexistent/hostapd
    run "${BATS_TEST_DIRNAME}/../clients.sh"
    [ "$status" -ne 0 ]
    [ "${lines[0]}" = "[Error] Control interface not available at /nonexistent/hostapd." ]
}

@test "socket dir present execs hostapd_cli all_sta" {
    export INTERFACE=wlan0
    mkdir -p "${BATS_TEST_TMPDIR}/hostapd"
    export CTRL_IFACE_DIR="${BATS_TEST_TMPDIR}/hostapd"
    run "${BATS_TEST_DIRNAME}/../clients.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"stub hostapd_cli: -p ${CTRL_IFACE_DIR} -i wlan0 all_sta"* ]]
}

@test "INTERFACE unset fails before control interface check" {
    run "${BATS_TEST_DIRNAME}/../clients.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"INTERFACE must be set"* ]]
}

@test "deauth with valid MAC execs hostapd_cli deauthenticate" {
    export INTERFACE=wlan0
    mkdir -p "${BATS_TEST_TMPDIR}/hostapd"
    export CTRL_IFACE_DIR="${BATS_TEST_TMPDIR}/hostapd"
    run "${BATS_TEST_DIRNAME}/../clients.sh" deauth aa:bb:cc:dd:ee:ff
    [ "$status" -eq 0 ]
    [[ "$output" == *"stub hostapd_cli: -p ${CTRL_IFACE_DIR} -i wlan0 deauthenticate aa:bb:cc:dd:ee:ff"* ]]
}

@test "deauth accepts uppercase MAC" {
    export INTERFACE=wlan0
    mkdir -p "${BATS_TEST_TMPDIR}/hostapd"
    export CTRL_IFACE_DIR="${BATS_TEST_TMPDIR}/hostapd"
    run "${BATS_TEST_DIRNAME}/../clients.sh" deauth AA:BB:CC:DD:EE:FF
    [ "$status" -eq 0 ]
    [[ "$output" == *"deauthenticate AA:BB:CC:DD:EE:FF"* ]]
}

@test "deauth with invalid MAC is rejected" {
    export INTERFACE=wlan0
    mkdir -p "${BATS_TEST_TMPDIR}/hostapd"
    export CTRL_IFACE_DIR="${BATS_TEST_TMPDIR}/hostapd"
    run "${BATS_TEST_DIRNAME}/../clients.sh" deauth not-a-mac
    [ "$status" -ne 0 ]
    [[ "$output" == *"[Error] Invalid MAC address 'not-a-mac'"* ]]
    [[ "$output" != *"stub hostapd_cli"* ]]
}

@test "deauth without MAC argument prints usage and exits non-zero" {
    export INTERFACE=wlan0
    mkdir -p "${BATS_TEST_TMPDIR}/hostapd"
    export CTRL_IFACE_DIR="${BATS_TEST_TMPDIR}/hostapd"
    run "${BATS_TEST_DIRNAME}/../clients.sh" deauth
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: clients.sh"* ]]
}

@test "unknown subcommand prints usage and exits non-zero" {
    export INTERFACE=wlan0
    mkdir -p "${BATS_TEST_TMPDIR}/hostapd"
    export CTRL_IFACE_DIR="${BATS_TEST_TMPDIR}/hostapd"
    run "${BATS_TEST_DIRNAME}/../clients.sh" bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: clients.sh"* ]]
}
