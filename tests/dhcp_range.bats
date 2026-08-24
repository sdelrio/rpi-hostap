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

@test "invalid IP in field 1 fails with field-specific error" {
    DHCP_RANGE="192.168.254.999,192.168.254.200,255.255.255.0,12h"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"field 1 '192.168.254.999' is not a valid IPv4 address"* ]]
}

@test "invalid IP in field 2 fails with field-specific error" {
    DHCP_RANGE="192.168.254.100,192.168.254.999,255.255.255.0,12h"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"field 2 '192.168.254.999' is not a valid IPv4 address"* ]]
}

@test "invalid netmask in field 3 fails with field-specific error" {
    DHCP_RANGE="192.168.254.100,192.168.254.200,255.0.0,12h"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"field 3 '255.0.0' is not a valid IPv4 address"* ]]
}

@test "non-numeric netmask in field 3 fails" {
    DHCP_RANGE="192.168.254.100,192.168.254.200,not-a-mask,12h"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"field 3 'not-a-mask' is not a valid IPv4 address"* ]]
}

@test "IP with leading-zero octet in field 1 fails" {
    DHCP_RANGE="192.168.254.010,192.168.254.200,255.255.255.0,12h"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"field 1"* ]]
}

@test "empty IP field fails validation" {
    DHCP_RANGE="192.168.254.100,,255.255.255.0,12h"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"field 2"* ]]
}

@test "lease time with invalid unit suffix fails" {
    DHCP_RANGE="192.168.254.100,192.168.254.200,255.255.255.0,12x"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"field 4 '12x' is not a valid lease time"* ]]
}

@test "non-numeric lease time fails" {
    DHCP_RANGE="192.168.254.100,192.168.254.200,255.255.255.0,infinite"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"field 4 'infinite' is not a valid lease time"* ]]
}

@test "negative lease time fails" {
    DHCP_RANGE="192.168.254.100,192.168.254.200,255.255.255.0,-12h"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
}

@test "plain integer lease time is accepted" {
    DHCP_RANGE="10.10.10.50,10.10.10.150,255.255.255.0,3600"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "${lines[@]: -1}" = "10.10.10.50,10.10.10.150,255.255.255.0,3600" ]
}

@test "minutes and seconds lease suffixes are accepted" {
    DHCP_RANGE="10.10.10.50,10.10.10.150,255.255.255.0,30m"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    DHCP_RANGE="10.10.10.50,10.10.10.150,255.255.255.0,45s"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
}

@test "default range rejected for SUBNET with wrong octet count" {
    SUBNET="192.168.254"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"Invalid SUBNET: '192.168.254' is not a valid IPv4 address"* ]]
}

@test "default range rejected for SUBNET with too many octets" {
    SUBNET="192.168.254.0.1"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"Invalid SUBNET"* ]]
}

# The container hardcodes a /24 layout (AP_ADDR/24 on the interface,
# ${SUBNET}/24 iptables rules), so non-/24 subnets are unsupported and
# rejected explicitly rather than silently producing a bogus /24 range.
@test "default range rejected for non-/24 SUBNET" {
    SUBNET="192.168.254.7"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"'192.168.254.7' is not a /24 network address"* ]]
}

@test "invalid DHCP_LEASE fails for default range" {
    DHCP_LEASE="forever"
    run compute_dhcp_range
    [ "$status" -eq 1 ]
    [[ "${lines[*]}" == *"Invalid DHCP_LEASE: 'forever' is not a valid lease time"* ]]
}
