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
    ip() { return 0; }
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

@test "apply_nat_rules fails fast naming nonexistent OUTGOINGS interface" {
    export OUTGOINGS="eth0,doesnotexist0"
    iptables() { echo "iptables $*"; }
    run apply_nat_rules
    [ "$status" -eq 1 ]
    [[ "${output}" == *"[Error] OUTGOINGS interface 'doesnotexist0' does not exist"* ]]
    [[ "${output}" != *"Setting iptables"* ]]
}

@test "apply_nat_rules proceeds when all OUTGOINGS interfaces exist (stubbed ip)" {
    export OUTGOINGS="eth0"
    ip() { return 0; }
    iptables() { echo "iptables $*"; }
    run apply_nat_rules
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Setting iptables for outgoing traffics on eth0..."* ]]
}

@test "validate_outgoings fails for missing interface without real network tools" {
    export OUTGOINGS="bogus9"
    export IP_BASE="${BATS_TEST_TMPDIR}/no-ip"
    run validate_outgoings
    [ "$status" -eq 1 ]
    [[ "${output}" == *"[Error] OUTGOINGS interface 'bogus9' does not exist"* ]]
}

@test "apply_nat_rules removes stale rule before adding (delete precedes append)" {
    local log="${BATS_TEST_TMPDIR}/iptables-order.log"
    iptables() { echo "$1" >> "${log}"; }
    apply_nat_rules
    [ "$(grep -n '^-D' "${log}" | head -1 | cut -d: -f1)" -lt "$(grep -n '^-A' "${log}" | head -1 | cut -d: -f1)" ]
}

@test "remove_nat_rules deletes generic rules without OUTGOINGS" {
    local log
    log=$(mktemp)
    OUTGOINGS="" INTERFACE="wlan0" SUBNET="192.168.254.0" \
    REPO_ROOT="$REPO_ROOT" LOG="$log" \
    run bash -c '
        iptables() { case "$*" in *"-D "*) echo "$*" >> "${LOG}" ;; esac ; }
        . "${REPO_ROOT}/lib/nat.sh"
        remove_nat_rules
    '
    [ "$status" -eq 0 ]
    grep -q -- "-t nat -D POSTROUTING -s 192.168.254.0/24 -j MASQUERADE" "${log}"
    grep -q -- "-D FORWARD -i wlan0 -j ACCEPT" "${log}"
    rm -f "${log}"
}

@test "apply_nat_rules uses DHCP_PREFIX when set" {
    DHCP_PREFIX=28
    iptables() { echo "iptables $*"; }
    run apply_nat_rules
    [ "$status" -eq 0 ]
    [[ "${output}" == *"iptables -t nat -A POSTROUTING -s 192.168.254.0/28 -j MASQUERADE"* ]]
}

@test "remove_nat_rules deletes rules per interface with OUTGOINGS" {
    local log
    log=$(mktemp)
    OUTGOINGS="eth0,eth1" INTERFACE="wlan0" SUBNET="192.168.254.0" \
    REPO_ROOT="$REPO_ROOT" LOG="$log" \
    run bash -c '
        iptables() { case "$*" in *"-D "*) echo "$*" >> "${LOG}" ;; esac ; }
        . "${REPO_ROOT}/lib/nat.sh"
        remove_nat_rules
    '
    [ "$status" -eq 0 ]
    grep -q -- "-t nat -D POSTROUTING -s 192.168.254.0/24 -o eth0 -j MASQUERADE" "${log}"
    grep -q -- "-t nat -D POSTROUTING -s 192.168.254.0/24 -o eth1 -j MASQUERADE" "${log}"
    grep -q -- "-D FORWARD -i wlan0 -o eth0 -j ACCEPT" "${log}"
    rm -f "${log}"
}

@test "set_sysctls skips sysctls already set to 1" {
    local dir="${BATS_TEST_TMPDIR}/proc"
    mkdir -p "${dir}"
    echo 1 > "${dir}/ip_dynaddr"
    SYSCTL_BASE="${dir}" run set_sysctls ip_dynaddr
    [ "$status" -eq 0 ]
    [[ "${output}" == *"ip_dynaddr already 1"* ]]
    [ "$(cat "${dir}/ip_dynaddr")" = "1" ]
}

@test "set_sysctls sets sysctl when value is not 1" {
    local dir="${BATS_TEST_TMPDIR}/proc"
    mkdir -p "${dir}"
    echo 0 > "${dir}/ip_forward"
    SYSCTL_BASE="${dir}" run set_sysctls ip_forward
    [ "$status" -eq 0 ]
    [ "$(cat "${dir}/ip_forward")" = "1" ]
}

@test "set_sysctls warns and continues for missing sysctl" {
    local dir="${BATS_TEST_TMPDIR}/proc"
    mkdir -p "${dir}"
    echo 0 > "${dir}/ip_forward"
    # ip_dynaddr lives under a nonexistent base so both read and write
    # fail regardless of privileges (CI may run as root).
    local missing="${BATS_TEST_TMPDIR}/no-such-proc"
    # shellcheck disable=SC2016
    run bash -c ". '${REPO_ROOT}/lib/nat.sh'; SYSCTL_BASE='${missing}' set_sysctls ip_dynaddr && SYSCTL_BASE='${dir}' set_sysctls ip_forward 2>&1"
    [ "$status" -eq 0 ]
    [[ "${output}" == *"[Warning] Cannot set ip_dynaddr"* ]]
    [ "$(cat "${dir}/ip_forward")" = "1" ]
}

@test "show_sysctls prints labeled values" {
    local dir="${BATS_TEST_TMPDIR}/proc"
    mkdir -p "${dir}"
    echo 1 > "${dir}/ip_dynaddr"
    echo 0 > "${dir}/ip_forward"
    SYSCTL_BASE="${dir}" run show_sysctls ip_dynaddr ip_forward
    [ "$status" -eq 0 ]
    [[ "${output}" == *"ip_dynaddr=1"* ]]
    [[ "${output}" == *"ip_forward=0"* ]]
}

@test "show_sysctls prints ? for missing sysctl" {
    local dir="${BATS_TEST_TMPDIR}/no-such-proc"
    SYSCTL_BASE="${dir}" run show_sysctls ip_dynaddr
    [ "$status" -eq 0 ]
    [[ "${output}" == *"ip_dynaddr=?"* ]]
}

@test "set_sysctls warns when write fails on non-numeric value" {
    local dir="${BATS_TEST_TMPDIR}/proc"
    mkdir -p "${dir}"
    echo "garbage" > "${dir}/ip_dynaddr"
    chmod 444 "${dir}/ip_dynaddr"
    # shellcheck disable=SC2016
    run bash -c ". '${REPO_ROOT}/lib/nat.sh'; SYSCTL_BASE='${dir}' set_sysctls ip_dynaddr 2>&1"
    [ "$status" -eq 0 ]
    [[ "${output}" == *"[Warning] Cannot set ip_dynaddr"* ]]
}
