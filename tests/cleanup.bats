#!/usr/bin/env bats

# Tests for graceful shutdown cleanup function

setup() {
    export INTERFACE="wlan0"
    export SUBNET="192.168.254.0"
    export OUTGOINGS=""
}

load_cleanup() {
    # shellcheck source=../lib/nat.sh
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/nat.sh"
    # shellcheck source=../lib/interface.sh
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/interface.sh"
    # shellcheck source=../lib/ipv6.sh
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/ipv6.sh"
    eval "$(sed -n '/^cleanup()/,/^}/p' wlanstart.sh)"
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
. '$PWD/lib/nat.sh'
. '$PWD/lib/interface.sh'
. '$PWD/lib/ipv6.sh'
$(sed -n '/^cleanup()/,/^}/p' wlanstart.sh)
INTERFACE="$INTERFACE"
SUBNET="$SUBNET"
OUTGOINGS="$OUTGOINGS"
IPV6="${IPV6:-0}"
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
    eval "$(sed -n '/^trap /p' wlanstart.sh)"
    local traps
    traps=$(trap -p)
    [[ "$traps" == *"handle_signal"*"SIGINT"* ]]
    [[ "$traps" == *"handle_signal"*"SIGTERM"* ]]
    [[ "$traps" == *"handle_signal"*"SIGHUP"* ]]
}

@test "cleanup prints shutdown message" {
    load_cleanup
    run cleanup
    [[ "$output" == *"Shutting down..."* ]]
}

@test "cleanup no longer kills daemon PIDs (multirun handles signals)" {
    ! grep -q 'DNSMASQ_PID\|HOSTAPD_PID' wlanstart.sh
    ! grep -qE 'wait "\$\{DNSMASQ_PID\}"' wlanstart.sh
}

@test "handle_signal forwards signal to multirun" {
    eval "$(sed -n '/^_MULTIRUN_PID=/p; /^_SIGNALED=/p; /^handle_signal()/,/^}/p; /^trap /p' wlanstart.sh)"
    _MULTIRUN_PID="4242"
    _SIGNALED=0
    run bash -c "
kill() { echo \"kill \$@\"; }
$(sed -n '/^handle_signal()/,/^}/p' "${BATS_TEST_DIRNAME}/../wlanstart.sh")
_MULTIRUN_PID=4242
_SIGNALED=0
handle_signal
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"kill 4242"* ]]
}

@test "wlanstart launches daemons via multirun (no explicit exec: multirun adds it)" {
    grep -q 'multirun "dnsmasq --no-daemon" "/usr/sbin/hostapd /etc/hostapd.conf"' wlanstart.sh
    ! grep -q 'multirun "exec' wlanstart.sh
    ! grep -q 'wait "${DNSMASQ_PID}" "${HOSTAPD_PID}"' wlanstart.sh
}

@test "cleanup prints iptables removal message" {
    load_cleanup
    run cleanup
    [[ "$output" == *"Removing iptables rules..."* ]]
}

@test "cleanup tears down iptables and interface without touching daemons" {
    run run_cleanup_mocked
    [[ "$output" != *"kill "* ]]
    [[ "$output" != *"wait "* ]]
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
