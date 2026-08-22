#!/usr/bin/env bats

# Logic shared with wlanstart.sh
REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
# shellcheck source=../lib/dhcp.sh
. "${REPO_ROOT}/lib/dhcp.sh"

setup() {
    export SUBNET="192.168.254.0"
    export AP_ADDR="192.168.254.1"
    export PRI_DNS="8.8.8.8"
    export SEC_DNS="8.8.4.4"
    export INTERFACE="wlan0"
    unset DHCP_RANGE
    unset DHCP_LEASE
}

@test "default DHCP_RANGE computed from SUBNET 192.168.254.0" {
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "${lines[@]: -1}" = "192.168.254.100,192.168.254.200,255.255.255.0,12h" ]
}

@test "default DHCP_RANGE computed from SUBNET 10.0.0.0" {
    SUBNET="10.0.0.0"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "${lines[@]: -1}" = "10.0.0.100,10.0.0.200,255.255.255.0,12h" ]
}

@test "default DHCP_RANGE computed from SUBNET 172.16.1.0" {
    SUBNET="172.16.1.0"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "${lines[@]: -1}" = "172.16.1.100,172.16.1.200,255.255.255.0,12h" ]
}

@test "explicit DHCP_RANGE is preserved" {
    DHCP_RANGE="10.10.10.50,10.10.10.150,255.255.255.0,24h"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "${lines[@]: -1}" = "10.10.10.50,10.10.10.150,255.255.255.0,24h" ]
}

@test "DHCP_LEASE used in default range" {
    DHCP_LEASE="24h"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "${lines[@]: -1}" = "192.168.254.100,192.168.254.200,255.255.255.0,24h" ]
}

@test "DHCP_LEASE ignored when DHCP_RANGE is explicit" {
    DHCP_RANGE="10.0.0.50,10.0.0.150,255.255.255.0,48h"
    DHCP_LEASE="24h"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "${lines[@]: -1}" = "10.0.0.50,10.0.0.150,255.255.255.0,48h" ]
}

@test "invalid DHCP_RANGE with too few commas fails" {
    DHCP_RANGE="10.0.0.50,10.0.0.150"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
}

@test "invalid DHCP_RANGE with too many commas fails" {
    DHCP_RANGE="10.0.0.50,10.0.0.150,255.255.255.0,12h,extra"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
}

@test "invalid DHCP_RANGE with no commas fails" {
    DHCP_RANGE="not-a-valid-range"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
}
