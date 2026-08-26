#!/usr/bin/env bats

# Tests exercise interface_setup() from lib/sys/interface.sh with a stubbed
# ip command, verifying the netmask-derived prefix (DHCP_PREFIX).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
# shellcheck source=../lib/sys/interface.sh
. "${REPO_ROOT}/lib/sys/interface.sh"

LOG=""

setup() {
    export INTERFACE="wlan0"
    export AP_ADDR="192.168.254.1"
    unset DHCP_PREFIX
    LOG="${BATS_TEST_TMPDIR}/ip.log"
    ip() { echo "ip $*" >> "${LOG}"; }
}

@test "interface_setup defaults to /24 when DHCP_PREFIX is unset" {
    run interface_setup
    [ "$status" -eq 0 ]
    grep -q -- "ip addr add 192.168.254.1/24 dev wlan0" "${LOG}"
}

@test "interface_setup uses DHCP_PREFIX for the interface address" {
    DHCP_PREFIX=28
    run interface_setup
    [ "$status" -eq 0 ]
    grep -q -- "ip addr add 192.168.254.1/28 dev wlan0" "${LOG}"
}

@test "interface_setup flushes addresses before assigning" {
    run interface_setup
    [ "$status" -eq 0 ]
    [ "$(grep -n 'addr add' "${LOG}" | cut -d: -f1)" -gt "$(grep -n 'addr flush' "${LOG}" | cut -d: -f1)" ]
}
