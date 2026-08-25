#!/usr/bin/env bats

# Logic shared with wlanstart.sh
REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
# shellcheck source=../lib/ipv6.sh
. "${REPO_ROOT}/lib/ipv6.sh"

setup() {
    export INTERFACE="wlan0"
    export OUTGOINGS=""
    ints=()
}

@test "IPv6 disabled by default: no dnsmasq conf" {
    unset IPV6
    run compute_dnsmasq_ipv6_conf
    [ "$status" -eq 1 ]
}

@test "IPv6 disabled explicitly (IPV6=0): no dnsmasq conf" {
    IPV6=0
    run compute_dnsmasq_ipv6_conf
    [ "$status" -eq 1 ]
}

@test "IPV6=1 emits RA/stateless DHCPv6 range for AP interface" {
    IPV6=1
    run compute_dnsmasq_ipv6_conf
    [ "$status" -eq 0 ]
    [ "${lines[@]: -1}" = "dhcp-range=::,constructor:wlan0,ra-names,stateless" ]
}

@test "apply_ipv6_rules with OUTGOINGS calls ip6tables per interface" {
    IPV6=1
    OUTGOINGS="eth0,eth1"
    parse_outgoings() { ints=("eth0" "eth1"); }
    interface_exists() { return 0; }
    ip6tables() { echo "ip6tables $*"; }
    parse_outgoings
    run apply_ipv6_rules
    [ "$status" -eq 0 ]
    [[ "${output}" == *"ip6tables -A FORWARD -i eth0 -o wlan0"* ]]
    [[ "${output}" == *"ip6tables -A FORWARD -i wlan0 -o eth1"* ]]
}

@test "apply_ipv6_rules fails fast naming nonexistent OUTGOINGS interface" {
    IPV6=1
    OUTGOINGS="bogus9"
    ip6tables() { echo "ip6tables $*"; }
    run apply_ipv6_rules
    [ "$status" -eq 1 ]
    [[ "${output}" == *"[Error] OUTGOINGS interface 'bogus9' does not exist"* ]]
}

@test "apply_ipv6_rules without OUTGOINGS uses generic rules" {
    IPV6=1
    ip6tables() { echo "ip6tables $*"; }
    run apply_ipv6_rules
    [ "$status" -eq 0 ]
    [[ "${output}" == *"ip6tables -A FORWARD -i wlan0 -j ACCEPT"* ]]
    [[ "${output}" == *"-o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT"* ]]
}

@test "remove_ipv6_rules deletes generic rules" {
    local log="${BATS_TEST_TMPDIR}/ip6tables.log"
    ip6tables() {
        if [ "$1" = "-D" ] ; then echo "delete $*" >> "${log}"; fi
        return 0
    }
    remove_ipv6_rules
    [ "$(grep -c delete "${log}")" -eq 2 ]
    [[ "$(cat "${log}")" == *"-i wlan0 -j ACCEPT"* ]]
}

@test "remove_ipv6_rules works standalone with OUTGOINGS (no nat.sh loaded)" {
    local log="${BATS_TEST_TMPDIR}/ip6tables-standalone.log"
    rm -f "${log}"
    REPO_ROOT="$REPO_ROOT" LOG="${log}" \
    run bash -c '
        ip6tables() { case "$*" in *"-D "*) echo "$*" >> "${LOG}" ;; esac ; }
        . "'"${REPO_ROOT}"'/lib/ipv6.sh"
        INTERFACE="wlan0" OUTGOINGS="eth0,eth1" remove_ipv6_rules
    '
    [ "$status" -eq 0 ]
    grep -q -- "-D FORWARD -i wlan0 -o eth0 -j ACCEPT" "${log}"
    grep -q -- "-D FORWARD -i eth1 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT" "${log}"
}

@test "apply_ipv6_rules works standalone with OUTGOINGS (no nat.sh loaded)" {
    run bash -c '
        ip6tables() { echo "ip6tables $*" >&2; }
        ip() { return 0; }
        . "'"${REPO_ROOT}"'/lib/ipv6.sh"
        INTERFACE="wlan0" OUTGOINGS="eth0,eth1" apply_ipv6_rules
    '
    [ "$status" -eq 0 ]
    [[ "${output}" == *"ip6tables -A FORWARD -i eth0 -o wlan0"* ]]
    [[ "${output}" == *"ip6tables -A FORWARD -i wlan0 -o eth1 -j ACCEPT"* ]]
}
