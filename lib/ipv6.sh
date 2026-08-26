# shellcheck shell=bash
# Shared optional IPv6 support used by wlanstart.sh and tests.
#
# IPv6 is off by default. When IPV6=1:
#   - net.ipv6.conf.all.forwarding is set to 1
#   - dnsmasq announces RA/stateless DHCPv6 on the AP interface
#   - ip6tables FORWARD rules mirror the IPv4 handling
#
# ipv6_compute_dnsmasq_conf prints the extra dnsmasq.conf line (or nothing
# when disabled). Messages go to stderr.

# Ensure nat_parse_outgoings (lib/nat.sh) is available so the rule functions
# below are self-contained and can be called without nat_apply_rules first.
if ! declare -F nat_parse_outgoings > /dev/null 2>&1 ; then
    # shellcheck source=lib/nat.sh
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nat.sh"
fi
ipv6_compute_dnsmasq_conf() {
    if [ "${IPV6:-0}" != "1" ] ; then
        echo "[Info] IPV6 not enabled, skipping IPv6 RA/DHCPv6 configuration." >&2
        return 1
    fi
    echo "dhcp-range=::,constructor:${INTERFACE},ra-names,stateless"
}

# ipv6_enable_forwarding sets the forwarding sysctl via /proc, tolerating
# missing entries. IPV6_SYSCTL_BASE can be overridden in tests to point at
# a stubbed procfs tree.
IPV6_SYSCTL_BASE="${IPV6_SYSCTL_BASE:-/proc/sys/net/ipv6}"

ipv6_enable_forwarding() {
    echo 1 > "${IPV6_SYSCTL_BASE}/conf/all/forwarding" 2>/dev/null \
        || echo "[Warning] Cannot set net.ipv6.conf.all.forwarding" >&2
}

# ipv6_apply_rules adds ip6tables FORWARD rules mirroring the IPv4 ones.
# shellcheck disable=SC2154
ipv6_apply_rules() {
    if [ "${OUTGOINGS}" ] ; then
        local int
        nat_validate_outgoings || return 1
        for int in "${ints[@]}" ; do
            ip6tables -D FORWARD -i "${int}" -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            ip6tables -A FORWARD -i "${int}" -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

            ip6tables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
            ip6tables -A FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT
        done
    else
        ip6tables -D FORWARD -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        ip6tables -A FORWARD -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

        ip6tables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
        ip6tables -A FORWARD -i "${INTERFACE}" -j ACCEPT
    fi
}

# ipv6_teardown removes the ip6tables rules, but only when IPv6 support
# was actually enabled at startup. Registered as a teardown hook so the
# IPV6 flag check lives next to the feature instead of in cleanup().
ipv6_teardown() {
    if [ "${IPV6:-0}" = "1" ] ; then
        echo "Removing ip6tables rules..."
        ipv6_remove_rules
    fi
}

# Teardown hook registration for the phase-based lifecycle (issue #241).
# Reverse-dependency order: registered after nat, before interface.
PHASE_TEARDOWN+=("ipv6_teardown")

# ipv6_remove_rules deletes the ip6tables rules added by ipv6_apply_rules.
ipv6_remove_rules() {
    if [ "${OUTGOINGS}" ] ; then
        local int
        nat_parse_outgoings
        for int in "${ints[@]}" ; do
            ip6tables -D FORWARD -i "${int}" -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            ip6tables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
        done
    else
        ip6tables -D FORWARD -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        ip6tables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
    fi
}
