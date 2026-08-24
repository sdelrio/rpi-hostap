#!/usr/bin/env bats

# Logic shared with wlanstart.sh
REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
# shellcheck source=../lib/nat.sh
. "${REPO_ROOT}/lib/nat.sh"

setup() {
    export INTERFACE="wlan0"
    export SUBNET="192.168.254.0"
    export OUTGOINGS=""
}

@test "parse_outgoings parses comma-separated interfaces" {
    OUTGOINGS="eth0,wlan0" parse_outgoings
    [ "${#ints[@]}" -eq 2 ]
    [ "${ints[0]}" = "eth0" ]
    [ "${ints[1]}" = "wlan0" ]
}

@test "parse_outgoings collapses repeated commas" {
    OUTGOINGS="eth0,,wlan0," parse_outgoings
    [ "${#ints[@]}" -eq 2 ]
}

@test "parse_outgoings yields empty array when OUTGOINGS unset" {
    OUTGOINGS="" parse_outgoings
    [ "${#ints[@]}" -eq 0 ]
}

@test "apply_nat_rules adds rules per interface with OUTGOINGS" {
    export OUTGOINGS="eth0,eth1"
    parse_outgoings
    iptables() { echo "iptables $*"; }
    run apply_nat_rules
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Setting iptables for outgoing traffics on eth0..."* ]]
    [[ "${output}" == *"iptables -t nat -A POSTROUTING -s 192.168.254.0/24 -o eth0 -j MASQUERADE"* ]]
    [[ "${output}" == *"iptables -t nat -A POSTROUTING -s 192.168.254.0/24 -o eth1 -j MASQUERADE"* ]]
    [[ "${output}" == *"iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT"* ]]
    [[ "${output}" == *"iptables -A FORWARD -i wlan0 -o eth1 -j ACCEPT"* ]]
}

@test "apply_nat_rules adds generic rules without OUTGOINGS" {
    iptables() { echo "iptables $*"; }
    run apply_nat_rules
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Setting iptables for outgoing traffics on all interfaces..."* ]]
    [[ "${output}" == *"iptables -t nat -A POSTROUTING -s 192.168.254.0/24 -j MASQUERADE"* ]]
    [[ "${output}" == *"iptables -A FORWARD -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT"* ]]
    [[ "${output}" == *"iptables -A FORWARD -i wlan0 -j ACCEPT"* ]]
}

@test "apply_nat_rules removes stale rule before adding (delete precedes append)" {
    local log="${BATS_TEST_TMPDIR}/iptables-order.log"
    iptables() { echo "$1" >> "${log}"; }
    apply_nat_rules
    [ "$(grep -n '^-D' "${log}" | head -1 | cut -d: -f1)" -lt "$(grep -n '^-A' "${log}" | head -1 | cut -d: -f1)" ]
}

@test "remove_nat_rules deletes generic rules without OUTGOINGS" {
    local log="${BATS_TEST_TMPDIR}/iptables.log"
    iptables() {
        if [ "$1" = "-D" ] ; then echo "$*" >> "${log}"; fi
        return 0
    }
    run remove_nat_rules
    [ "$status" -eq 0 ]
    [[ "$(cat "${log}")" == *"-t nat -D POSTROUTING -s 192.168.254.0/24 -j MASQUERADE"* ]]
    [[ "$(cat "${log}")" == *"-D FORWARD -i wlan0 -j ACCEPT"* ]]
}

@test "remove_nat_rules deletes rules per interface with OUTGOINGS" {
    export OUTGOINGS="eth0,eth1"
    local log="${BATS_TEST_TMPDIR}/iptables-multi.log"
    iptables() {
        if [ "$1" = "-D" ] ; then echo "$*" >> "${log}"; fi
        return 0
    }
    run remove_nat_rules
    [ "$status" -eq 0 ]
    [[ "$(cat "${log}")" == *"-t nat -D POSTROUTING -s 192.168.254.0/24 -o eth0 -j MASQUERADE"* ]]
    [[ "$(cat "${log}")" == *"-t nat -D POSTROUTING -s 192.168.254.0/24 -o eth1 -j MASQUERADE"* ]]
    [[ "$(cat "${log}")" == *"-D FORWARD -i wlan0 -o eth0 -j ACCEPT"* ]]
}
