# shellcheck shell=bash
# DHCP server config emission (issue #238): pure module, prints the
# generated config to stdout from the current environment. No external tools.

# Emit the DHCP server config to stdout from the current environment.
dnsmasq_conf_emit() {
    local dhcp_range ipv6_conf=""
    # Reuse the range computed at startup (DHCP_RANGE_COMPUTED) when
    # available so dhcp_compute_range (and its warnings) runs only once;
    # validation mode and tests without it still compute on demand.
    if [ -n "${DHCP_RANGE_COMPUTED:-}" ] ; then
        dhcp_range=${DHCP_RANGE_COMPUTED}
    else
        dhcp_range=$(dhcp_compute_range) || return 1
    fi
    if [ "${IPV6:-0}" = "1" ] ; then
        ipv6_conf=$(ipv6_compute_dnsmasq_conf)
    fi

    cat <<EOF
interface=${INTERFACE}
bind-dynamic
dhcp-authoritative
dhcp-leasefile=${DHCP_LEASE_FILE:-/tmp/dnsmasq.leases}
dhcp-range=${dhcp_range}
dhcp-option=option:router,${AP_ADDR}
dhcp-option=option:dns-server,${PRI_DNS},${SEC_DNS}
${ipv6_conf}
EOF
}
