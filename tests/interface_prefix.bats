#!/usr/bin/env bats

# Tests exercise setup_interface() from lib/interface.sh with a stubbed
# ip command, verifying the netmask-derived prefix (DHCP_PREFIX).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
# shellcheck source=../lib/interface.sh
. "${REPO_ROOT}/lib/interface.sh"

LOG=""

setup() {
    export INTERFACE="wlan0"
    export AP_ADDR="192.168.254.1"
    unset DHCP_PREFIX
    LOG="${BATS_TEST_TMPDIR}/ip.log"
    ip() { echo "ip $*" >> "${LOG}"; }
}

@test "setup_interface defaults to /24 when DHCP_PREFIX is unset" {
    run setup_interface
    [ "$status" -eq 0 ]
    grep -q -- "ip addr add 192.168.254.1/24 dev wlan0" "${LOG}"
}

@test "setup_interface uses DHCP_PREFIX for the interface address" {
    DHCP_PREFIX=28
    run setup_interface
    [ "$status" -eq 0 ]
    grep -q -- "ip addr add 192.168.254.1/28 dev wlan0" "${LOG}"
}

@test "setup_interface flushes addresses before assigning" {
    run setup_interface
    [ "$status" -eq 0 ]
    [ "$(grep -n 'addr add' "${LOG}" | cut -d: -f1)" -gt "$(grep -n 'addr flush' "${LOG}" | cut -d: -f1)" ]
}
