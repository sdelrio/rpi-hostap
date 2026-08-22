# shellcheck shell=bash
# Shared DHCP_RANGE logic used by wlanstart.sh and tests.
#
# compute_dhcp_range reads SUBNET, DHCP_RANGE and DHCP_LEASE from the
# environment. If DHCP_RANGE is unset it computes a default from SUBNET
# (.100 - .200 / 255.255.255.0). Otherwise validates the format must
# contain exactly 3 commas (start_ip,end_ip,netmask,lease).
# Prints the resulting range to stdout. Messages go to stderr.
# Returns non-zero for invalid DHCP_RANGE formats.
compute_dhcp_range() {
    : "${DHCP_LEASE:=12h}"
    if [ -z "${DHCP_RANGE}" ] ; then
        SUBNET_PREFIX=$(echo "$SUBNET" | rev | cut -d. -f2- | rev)
        DHCP_RANGE="${SUBNET_PREFIX}.100,${SUBNET_PREFIX}.200,255.255.255.0,${DHCP_LEASE}"
        echo "[Warning] DHCP_RANGE not set, using default: $DHCP_RANGE" >&2
    else
        COMMA_COUNT=$(echo "${DHCP_RANGE}" | tr -cd ',' | wc -c)
        if [ "${COMMA_COUNT}" -ne 3 ] ; then
            echo "[Error] Invalid DHCP_RANGE format: '${DHCP_RANGE}'"
            echo "  Expected: start_ip,end_ip,netmask,lease_time"
            echo "  Example: 192.168.254.100,192.168.254.200,255.255.255.0,12h"
            return 1
        fi
    fi
    echo "${DHCP_RANGE}"
}
