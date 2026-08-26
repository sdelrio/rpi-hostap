# shellcheck shell=bash
# Shared DHCP_RANGE logic used by wlanstart.sh and tests.
#
# dhcp_compute_range reads SUBNET, DHCP_RANGE and DHCP_LEASE from the
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
# Semantic validation (explicit DHCP_RANGE only): start must not exceed
# end (numeric 32-bit compare), both endpoints must lie inside
# ${SUBNET}/${prefix}, and the pool must not contain AP_ADDR. AP_ADDR
# overlap is rejected outright rather than warned: the AP has a static
# address, so a lease collision is always a configuration error.
# Additionally AP_ADDR itself must lie inside ${SUBNET}/${prefix}
# (AP_ADDR & netmask == SUBNET), otherwise clients would be handed an
# unreachable gateway address.
#
# Prints the resulting range to stdout. Messages go to stderr.
# Returns non-zero for invalid input.

# shellcheck source=lib/validation.sh
. "$(dirname "${BASH_SOURCE[0]}")/validation.sh"

# dhcp_ip_to_int converts a dotted-quad IPv4 address (already validated)
# into its 32-bit integer value so ranges can be compared numerically.
dhcp_ip_to_int() {
    local o1 o2 o3 o4
    IFS=. read -r o1 o2 o3 o4 <<<"${1}"
    echo $(( (o1 << 24) | (o2 << 16) | (o3 << 8) | o4 ))
}

# dhcp_check_ap_addr_in_subnet verifies that AP_ADDR lies inside
# ${SUBNET}/<prefix> for the given dotted-decimal netmask, i.e.
# AP_ADDR & netmask == SUBNET. Emits an error on stderr and returns
# non-zero otherwise. Skips silently when AP_ADDR or SUBNET is unset
# or not a valid IPv4 address (those cases are reported elsewhere).
dhcp_check_ap_addr_in_subnet() {
    local netmask=${1:-}
    if [ -z "${AP_ADDR:-}" ] || [ -z "${SUBNET:-}" ] ; then
        return 0
    fi
    if ! validation_check_ipv4 "${AP_ADDR}" || ! validation_check_ipv4 "${SUBNET}" ; then
        return 0
    fi
    local m1 m2 m3 m4 ap_masked subnet_int
    IFS=. read -r m1 m2 m3 m4 <<<"${netmask}"
    ap_masked=$(( $(dhcp_ip_to_int "${AP_ADDR}") & (m1 << 24 | m2 << 16 | m3 << 8 | m4) ))
    subnet_int=$(dhcp_ip_to_int "${SUBNET}")
    if [ "${ap_masked}" -ne "${subnet_int}" ] ; then
        echo "[Error] AP_ADDR '${AP_ADDR}' is not inside SUBNET ${SUBNET}/${DHCP_PREFIX}" >&2
        return 1
    fi
}

# A dnsmasq lease time is a positive integer optionally followed by
# h (hours), m (minutes) or s (seconds), e.g. 12h, 30m, 3600.
dhcp_validate_lease_time() {
    [[ "${1:-}" =~ ^[0-9]+[hms]?$ ]]
}

dhcp_compute_range() {
    # DHCP_LEASE default is applied centrally by lib/env.sh (#237)
    if [ ! "${DHCP_LEASE}" ] || ! dhcp_validate_lease_time "${DHCP_LEASE}" ; then
        echo "[Error] Invalid DHCP_LEASE: '${DHCP_LEASE}' is not a valid lease time." >&2
        echo "  Expected: integer optionally followed by h/m/s (e.g. 12h, 3600)"
        return 1
    fi

    if [ -z "${DHCP_RANGE}" ] ; then
        if [ -z "${SUBNET:-}" ] ; then
            echo "[Error] SUBNET not set: cannot compute default DHCP_RANGE." >&2
            return 1
        fi
        if ! validation_check_ipv4 "${SUBNET}" ; then
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
        if ! dhcp_check_ap_addr_in_subnet "255.255.255.0" ; then
            return 1
        fi
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
        if ! validation_check_ipv4 "${start_ip}" ; then
            echo "[Error] Invalid DHCP_RANGE: field 1 '${start_ip}' is not a valid IPv4 address" >&2
            return 1
        fi
        if ! validation_check_ipv4 "${end_ip}" ; then
            echo "[Error] Invalid DHCP_RANGE: field 2 '${end_ip}' is not a valid IPv4 address" >&2
            return 1
        fi
        if ! validation_check_ipv4 "${netmask}" ; then
            echo "[Error] Invalid DHCP_RANGE: field 3 '${netmask}' is not a valid IPv4 address" >&2
            return 1
        fi
        # Derive the CIDR prefix from the netmask; this propagates to the
        # interface address (${AP_ADDR}/<prefix>) and NAT rules.
        if ! DHCP_PREFIX=$(validation_netmask_to_prefix "${netmask}") ; then
            echo "[Error] Invalid DHCP_RANGE: field 3 '${netmask}' is not a usable netmask" >&2
            return 1
        fi
        # SUBNET must be the network address for the configured mask.
        if [ -n "${SUBNET:-}" ] && validation_check_ipv4 "${SUBNET}" \
           && ! validation_is_network_address "${SUBNET}" "${netmask}" ; then
            echo "[Error] Invalid SUBNET: '${SUBNET}' is not a network address for mask ${netmask} (host bits must be 0)." >&2
            return 1
        fi
        export DHCP_PREFIX

        # Semantic checks on the parsed fields:
        # 1. start must not come after end (numeric compare on the
        #    full 32-bit address, so multi-octet ranges work too).
        # 2. Both endpoints must lie inside ${SUBNET}/${prefix}
        #    (mask arithmetic), otherwise dnsmasq would hand out
        #    addresses outside the AP network.
        # 3. The pool must not contain AP_ADDR itself: the access
        #    point has a static address and a lease collision would
        #    break connectivity. We reject outright rather than warn -
        #    an overlapping pool is always a configuration error.
        if [ "$(dhcp_ip_to_int "${start_ip}")" -gt "$(dhcp_ip_to_int "${end_ip}")" ] ; then
            echo "[Error] Invalid DHCP_RANGE: field 1 '${start_ip}' is greater than field 2 '${end_ip}' (start must not exceed end)." >&2
            return 1
        fi
        if [ -n "${SUBNET:-}" ] && validation_check_ipv4 "${SUBNET}" ; then
            local subnet_int addr masked mask_int
            subnet_int=$(dhcp_ip_to_int "${SUBNET}")
            IFS=. read -r m1 m2 m3 m4 <<<"${netmask}"
            mask_int=$(( (m1 << 24) | (m2 << 16) | (m3 << 8) | m4 ))
            for addr in "${start_ip}" "${end_ip}" ; do
                masked=$(( $(dhcp_ip_to_int "${addr}") & mask_int ))
                if [ "${masked}" -ne "${subnet_int}" ] ; then
                    echo "[Error] Invalid DHCP_RANGE: '${addr}' is outside subnet ${SUBNET}/${DHCP_PREFIX} (mask ${netmask})." >&2
                    return 1
                fi
            done
            if ! dhcp_check_ap_addr_in_subnet "${netmask}" ; then
                return 1
            fi
        fi
        if [ -n "${AP_ADDR:-}" ] && validation_check_ipv4 "${AP_ADDR}" ; then
            local ap_int
            ap_int=$(dhcp_ip_to_int "${AP_ADDR}")
            if [ "${ap_int}" -ge "$(dhcp_ip_to_int "${start_ip}")" ] \
               && [ "${ap_int}" -le "$(dhcp_ip_to_int "${end_ip}")" ] ; then
                echo "[Error] Invalid DHCP_RANGE: '${start_ip}','${end_ip}' contains AP_ADDR '${AP_ADDR}' (the AP address must stay out of the DHCP pool)." >&2
                return 1
            fi
        fi

        if ! dhcp_validate_lease_time "${lease_time}" ; then
            echo "[Error] Invalid DHCP_RANGE: field 4 '${lease_time}' is not a valid lease time" >&2
            echo "  Expected: integer optionally followed by h/m/s (e.g. 12h, 3600)" >&2
            return 1
        fi
    fi
    echo "${DHCP_RANGE}"
}
