# shellcheck shell=bash
# Shared optional IPv6 support used by wlanstart.sh and tests.
#
# IPv6 is off by default. When IPV6=1:
#   - net.ipv6.conf.all.forwarding is set to 1
#   - dnsmasq announces RA/stateless DHCPv6 on the AP interface
#   - ip6tables FORWARD rules mirror the IPv4 handling
#
# compute_dnsmasq_ipv6_conf prints the extra dnsmasq.conf line (or nothing
# when disabled). Messages go to stderr.
compute_dnsmasq_ipv6_conf() {
    if [ "${IPV6:-0}" != "1" ] ; then
        echo "[Info] IPV6 not enabled, skipping IPv6 RA/DHCPv6 configuration." >&2
        return 1
    fi
    echo "dhcp-range=::,constructor:${INTERFACE},ra-names,stateless"
}

# enable_ipv6_forwarding sets the forwarding sysctl via /proc.
enable_ipv6_forwarding() {
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
}

# apply_ipv6_rules adds ip6tables FORWARD rules mirroring the IPv4 ones.
# ints is populated by parse_outgoings from lib/nat.sh.
# shellcheck disable=SC2154
apply_ipv6_rules() {
    if [ "${OUTGOINGS}" ] ; then
        local int
        for int in "${ints[@]}" ; do
            ip6tables -D FORWARD -i "${int}" -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            ip6tables -A FORWARD -i "${int}" -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT

            ip6tables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
            ip6tables -A FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT
        done
    else
        ip6tables -D FORWARD -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        ip6tables -A FORWARD -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT

        ip6tables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
        ip6tables -A FORWARD -i "${INTERFACE}" -j ACCEPT
    fi
}

# remove_ipv6_rules deletes the ip6tables rules added by apply_ipv6_rules.
# shellcheck disable=SC2154
remove_ipv6_rules() {
    if [ "${OUTGOINGS}" ] ; then
        local int
        for int in "${ints[@]}" ; do
            ip6tables -D FORWARD -i "${int}" -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            ip6tables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
        done
    else
        ip6tables -D FORWARD -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        ip6tables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
    fi
}
