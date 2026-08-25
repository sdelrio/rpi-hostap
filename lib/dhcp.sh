# shellcheck shell=bash
# Shared DHCP_RANGE logic used by wlanstart.sh and tests.
#
# compute_dhcp_range reads SUBNET, DHCP_RANGE and DHCP_LEASE from the
# environment. If DHCP_RANGE is unset it computes a default from SUBNET
# (.100 - .200 / 255.255.255.0). Otherwise each field of the explicit
# DHCP_RANGE (start_ip,end_ip,netmask,lease_time) is validated: the first
# three fields must be well-formed IPv4 addresses and the fourth must be a
# dnsmasq-style lease time (integer optionally followed by h/m/s).
#
# SUBNET handling: the CIDR prefix comes from the DHCP_RANGE netmask
# field and propagates to the interface address (${AP_ADDR}/<prefix>)
# and NAT rules. When DHCP_RANGE is unset a default /24 range is
# computed from SUBNET, so SUBNET must then be a valid IPv4 address
# whose last octet is 0 (a /24 network address). With an explicit
# DHCP_RANGE, any mask is accepted as long as SUBNET is its network
# address; anything else - including wrong octet counts - is rejected
# explicitly instead of being silently mangled into a bogus range.
# The derived prefix is exported as DHCP_PREFIX for lib/interface.sh
# and lib/nat.sh.
#
# Prints the resulting range to stdout. Messages go to stderr.
# Returns non-zero for invalid input.

# shellcheck source=lib/validation.sh
. "$(dirname "${BASH_SOURCE[0]}")/validation.sh"

# A dnsmasq lease time is a positive integer optionally followed by
# h (hours), m (minutes) or s (seconds), e.g. 12h, 30m, 3600.
validate_lease_time() {
    [[ "${1:-}" =~ ^[0-9]+[hms]?$ ]]
}

compute_dhcp_range() {
    : "${DHCP_LEASE:=12h}"
    if [ ! "${DHCP_LEASE}" ] || ! validate_lease_time "${DHCP_LEASE}" ; then
        echo "[Error] Invalid DHCP_LEASE: '${DHCP_LEASE}' is not a valid lease time." >&2
        echo "  Expected: integer optionally followed by h/m/s (e.g. 12h, 3600)"
        return 1
    fi

    if [ -z "${DHCP_RANGE}" ] ; then
        if [ -z "${SUBNET:-}" ] ; then
            echo "[Error] SUBNET not set: cannot compute default DHCP_RANGE." >&2
            return 1
        fi
        if ! validate_ipv4 "${SUBNET}" ; then
            echo "[Error] Invalid SUBNET: '${SUBNET}' is not a valid IPv4 address." >&2
            return 1
        fi
        # Only /24 networks are supported for the default range.
        if [ "${SUBNET##*.}" != "0" ] ; then
            echo "[Error] Invalid SUBNET: '${SUBNET}' is not a network address for the default /24 mask (last octet must be 0)." >&2
            return 1
        fi
        local prefix=${SUBNET%.*}
        DHCP_RANGE="${prefix}.100,${prefix}.200,255.255.255.0,${DHCP_LEASE}"
        DHCP_PREFIX=24
        export DHCP_PREFIX
        echo "[Warning] DHCP_RANGE not set, using default: $DHCP_RANGE" >&2
    else
        local COMMA_COUNT
        COMMA_COUNT=$(echo "${DHCP_RANGE}" | tr -cd ',' | wc -c)
        if [ "${COMMA_COUNT}" -ne 3 ] ; then
            echo "[Error] Invalid DHCP_RANGE format: '${DHCP_RANGE}'" >&2
            echo "  Expected: start_ip,end_ip,netmask,lease_time" >&2
            echo "  Example: 192.168.254.100,192.168.254.200,255.255.255.0,12h" >&2
            return 1
        fi

        local start_ip end_ip netmask lease_time
        IFS=',' read -r start_ip end_ip netmask lease_time <<<"${DHCP_RANGE}"
        if ! validate_ipv4 "${start_ip}" ; then
            echo "[Error] Invalid DHCP_RANGE: field 1 '${start_ip}' is not a valid IPv4 address" >&2
            return 1
        fi
        if ! validate_ipv4 "${end_ip}" ; then
            echo "[Error] Invalid DHCP_RANGE: field 2 '${end_ip}' is not a valid IPv4 address" >&2
            return 1
        fi
        if ! validate_ipv4 "${netmask}" ; then
            echo "[Error] Invalid DHCP_RANGE: field 3 '${netmask}' is not a valid IPv4 address" >&2
            return 1
        fi
        # Derive the CIDR prefix from the netmask; this propagates to the
        # interface address (${AP_ADDR}/<prefix>) and NAT rules.
        if ! DHCP_PREFIX=$(netmask_to_prefix "${netmask}") ; then
            echo "[Error] Invalid DHCP_RANGE: field 3 '${netmask}' is not a usable netmask" >&2
            return 1
        fi
        # SUBNET must be the network address for the configured mask.
        if [ -n "${SUBNET:-}" ] && validate_ipv4 "${SUBNET}" \
           && ! is_network_address "${SUBNET}" "${netmask}" ; then
            echo "[Error] Invalid SUBNET: '${SUBNET}' is not a network address for mask ${netmask} (host bits must be 0)." >&2
            return 1
        fi
        export DHCP_PREFIX
        if ! validate_lease_time "${lease_time}" ; then
            echo "[Error] Invalid DHCP_RANGE: field 4 '${lease_time}' is not a valid lease time" >&2
            echo "  Expected: integer optionally followed by h/m/s (e.g. 12h, 3600)" >&2
            return 1
        fi
    fi
    echo "${DHCP_RANGE}"
}
