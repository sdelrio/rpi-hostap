#!/usr/bin/env bats

# Helper to extract DHCP logic from wlanstart.sh
# We simulate the relevant parts without running the full script

setup() {
    export SUBNET="192.168.254.0"
    export AP_ADDR="192.168.254.1"
    export PRI_DNS="8.8.8.8"
    export SEC_DNS="8.8.4.4"
    export INTERFACE="wlan0"
    unset DHCP_RANGE
    unset DHCP_LEASE
}

compute_dhcp_range() {
    # Replicate the logic from wlanstart.sh
    true ${DHCP_LEASE:=12h}
    if [ -z "${DHCP_RANGE}" ] ; then
        SUBNET_PREFIX=$(echo $SUBNET | rev | cut -d. -f2- | rev)
        DHCP_RANGE="${SUBNET_PREFIX}.100,${SUBNET_PREFIX}.200,255.255.255.0,${DHCP_LEASE}"
    else
        COMMA_COUNT=$(echo "${DHCP_RANGE}" | tr -cd ',' | wc -c)
        if [ "${COMMA_COUNT}" -ne 3 ] ; then
            echo "[Error] Invalid DHCP_RANGE format: '${DHCP_RANGE}'" >&2
            return 1
        fi
    fi
    echo "${DHCP_RANGE}"
}

@test "default DHCP_RANGE computed from SUBNET 192.168.254.0" {
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "$output" = "192.168.254.100,192.168.254.200,255.255.255.0,12h" ]
}

@test "default DHCP_RANGE computed from SUBNET 10.0.0.0" {
    SUBNET="10.0.0.0"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "$output" = "10.0.0.100,10.0.0.200,255.255.255.0,12h" ]
}

@test "default DHCP_RANGE computed from SUBNET 172.16.1.0" {
    SUBNET="172.16.1.0"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "$output" = "172.16.1.100,172.16.1.200,255.255.255.0,12h" ]
}

@test "explicit DHCP_RANGE is preserved" {
    DHCP_RANGE="10.10.10.50,10.10.10.150,255.255.255.0,24h"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "$output" = "10.10.10.50,10.10.10.150,255.255.255.0,24h" ]
}

@test "DHCP_LEASE used in default range" {
    DHCP_LEASE="24h"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "$output" = "192.168.254.100,192.168.254.200,255.255.255.0,24h" ]
}

@test "DHCP_LEASE ignored when DHCP_RANGE is explicit" {
    DHCP_RANGE="10.0.0.50,10.0.0.150,255.255.255.0,48h"
    DHCP_LEASE="24h"
    run compute_dhcp_range
    [ "$status" -eq 0 ]
    [ "$output" = "10.0.0.50,10.0.0.150,255.255.255.0,48h" ]
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
