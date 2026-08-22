#!/usr/bin/env bats

# Tests for graceful shutdown cleanup function

setup() {
    export INTERFACE="wlan0"
    export SUBNET="192.168.254.0"
    export OUTGOINGS=""
    export HOSTAPD_PID=""
    export DNSMASQ_PID=""
}

load_cleanup() {
    eval "$(sed -n '/^parse_outgoings()/,/^}/p; /^cleanup()/,/^}/p; /^trap cleanup/p' wlanstart.sh)"
}

run_cleanup_mocked() {
    local mock_log
    mock_log=$(mktemp)
    export _MOCK_LOG="$mock_log"

    bash -c "
_mock_log() { echo \"\$@\" >> \"$_MOCK_LOG\"; }
iptables() { _mock_log \"iptables \$@\"; }
ip() { _mock_log \"ip \$@\"; }
kill() { _mock_log \"kill \$@\"; }
wait() { _mock_log \"wait \$@\"; }
$(sed -n '/^parse_outgoings()/,/^}/p; /^cleanup()/,/^}/p' wlanstart.sh)
INTERFACE=\"$INTERFACE\"
SUBNET=\"$SUBNET\"
OUTGOINGS=\"$OUTGOINGS\"
HOSTAPD_PID=\"$HOSTAPD_PID\"
DNSMASQ_PID=\"$DNSMASQ_PID\"
cleanup
"
    cat "$mock_log"
    rm -f "$mock_log"
}

@test "parse_outgoings parses comma-separated interfaces" {
    load_cleanup
    OUTGOINGS="eth0,wlan0" parse_outgoings
    [ "${#ints[@]}" -eq 2 ]
    [ "${ints[0]}" = "eth0" ]
    [ "${ints[1]}" = "wlan0" ]
}

@test "parse_outgoings collapses repeated commas" {
    load_cleanup
    OUTGOINGS="eth0,,wlan0," parse_outgoings
    [ "${#ints[@]}" -eq 2 ]
    [ "${ints[0]}" = "eth0" ]
    [ "${ints[1]}" = "wlan0" ]
}

@test "parse_outgoings yields empty array when OUTGOINGS unset" {
    load_cleanup
    OUTGOINGS="" parse_outgoings
    [ "${#ints[@]}" -eq 0 ]
}

@test "cleanup function is defined" {
    load_cleanup
    [ "$(type -t cleanup)" = "function" ]
}

@test "trap is set for SIGINT SIGTERM SIGHUP" {
    load_cleanup
    local traps
    traps=$(trap -p)
    [[ "$traps" == *"cleanup"*"SIGINT"* ]]
    [[ "$traps" == *"cleanup"*"SIGTERM"* ]]
    [[ "$traps" == *"cleanup"*"SIGHUP"* ]]
}

@test "cleanup prints shutdown message" {
    load_cleanup
    run cleanup
    [[ "$output" == *"Shutting down..."* ]]
}

@test "cleanup prints iptables removal message" {
    load_cleanup
    run cleanup
    [[ "$output" == *"Removing iptables rules..."* ]]
}

@test "cleanup kills hostapd and dnsmasq PIDs" {
    export HOSTAPD_PID="1234"
    export DNSMASQ_PID="5678"
    run run_cleanup_mocked
    [[ "$output" == *"kill 1234"* ]]
    [[ "$output" == *"kill 5678"* ]]
    [[ "$output" == *"wait 1234"* ]]
    [[ "$output" == *"wait 5678"* ]]
}

@test "cleanup removes iptables rules without OUTGOINGS" {
    run run_cleanup_mocked
    [[ "$output" == *"iptables -t nat -D POSTROUTING -s 192.168.254.0/24 -j MASQUERADE"* ]]
    [[ "$output" == *"iptables -D FORWARD -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT"* ]]
    [[ "$output" == *"iptables -D FORWARD -i wlan0 -j ACCEPT"* ]]
}

@test "cleanup removes iptables rules with single OUTGOING" {
    export OUTGOINGS="eth0"
    run run_cleanup_mocked
    [[ "$output" == *"iptables -t nat -D POSTROUTING -s 192.168.254.0/24 -o eth0 -j MASQUERADE"* ]]
    [[ "$output" == *"iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT"* ]]
    [[ "$output" == *"iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT"* ]]
}

@test "cleanup removes iptables rules with multiple OUTGOINGS" {
    export OUTGOINGS="eth0,eth1"
    run run_cleanup_mocked
    [[ "$output" == *"Removing iptables for outgoing traffics on eth0..."* ]]
    [[ "$output" == *"Removing iptables for outgoing traffics on eth1..."* ]]
    [[ "$output" == *"iptables -t nat -D POSTROUTING -s 192.168.254.0/24 -o eth0 -j MASQUERADE"* ]]
    [[ "$output" == *"iptables -t nat -D POSTROUTING -s 192.168.254.0/24 -o eth1 -j MASQUERADE"* ]]
}

@test "cleanup flushes interface address and brings link down" {
    run run_cleanup_mocked
    [[ "$output" == *"ip addr flush dev wlan0"* ]]
    [[ "$output" == *"ip link set wlan0 down"* ]]
}

@test "cleanup skips interface teardown when INTERFACE unset" {
    export INTERFACE=""
    run run_cleanup_mocked
    [[ "$output" != *"ip addr flush"* ]]
    [[ "$output" != *"ip link set"* ]]
}

@test "cleanup exits with status 0" {
    load_cleanup
    run cleanup
    [ "$status" -eq 0 ]
}
