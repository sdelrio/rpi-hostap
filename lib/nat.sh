# shellcheck shell=bash
# Shared IPv4 NAT logic used by wlanstart.sh and tests.
#
# nat_parse_outgoings fills ints with the comma-separated OUTGOINGS interfaces.

nat_parse_outgoings() {
    ints=()
    local -a raw
    local i
    IFS=',' read -r -a raw <<<"${OUTGOINGS}"
    for i in "${raw[@]}" ; do
        [ -n "${i}" ] && ints+=("${i}")
    done
}

# IP_BASE can be overridden in tests to point at a stubbed ip tool
# (e.g. when validating OUTGOINGS interfaces without real network tools).
IP_BASE="${IP_BASE:-ip}"

# nat_interface_exists returns 0 when the given network interface exists.
nat_interface_exists() {
    "${IP_BASE}" link show "$1" > /dev/null 2>&1
}

# nat_validate_outgoings checks every parsed OUTGOINGS interface exists,
# failing fast with an error naming the offending interface.
nat_validate_outgoings() {
    local int
    nat_parse_outgoings
    for int in "${ints[@]}" ; do
        if ! nat_interface_exists "${int}" ; then
            echo "[Error] OUTGOINGS interface '${int}' does not exist" >&2
            return 1
        fi
    done
}

# nat_apply_rules adds iptables MASQUERADE/FORWARD rules for outgoing traffic.
nat_apply_rules() {
    if [ "${OUTGOINGS}" ] ; then
        local int
        nat_validate_outgoings || return 1
        for int in "${ints[@]}"
        do
            echo "Setting iptables for outgoing traffics on ${int}..."

            iptables -t nat -D POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -o "${int}" -j MASQUERADE > /dev/null 2>&1 || true
            iptables -t nat -A POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -o "${int}" -j MASQUERADE

            iptables -D FORWARD -i "${int}" -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            iptables -A FORWARD -i "${int}" -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

            iptables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
            iptables -A FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT
        done
    else
        echo "Setting iptables for outgoing traffics on all interfaces..."

        iptables -t nat -D POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -j MASQUERADE > /dev/null 2>&1 || true
        iptables -t nat -A POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -j MASQUERADE

        iptables -D FORWARD -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        iptables -A FORWARD -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

        iptables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
        iptables -A FORWARD -i "${INTERFACE}" -j ACCEPT
    fi
}

# nat_set_sysctls enables the given ipv4 sysctls, tolerating missing entries
# (e.g. kernels built without ip_dynaddr). SYSCTL_BASE can be overridden
# in tests to point at a stubbed procfs tree.
SYSCTL_BASE="${SYSCTL_BASE:-/proc/sys/net/ipv4}"

nat_set_sysctls() {
    local i val
    for i in "$@" ; do
        val="$(cat "${SYSCTL_BASE}/${i}" 2>/dev/null || echo 0)"
        case "${val}" in
            1) echo "${i} already 1" ;;
            *) echo "1" > "${SYSCTL_BASE}/${i}" 2>/dev/null \
                || echo "[Warning] Cannot set ${i}" >&2 ;;
        esac
    done
}

# nat_show_sysctls prints labeled values for the given ipv4 sysctls (#194).
nat_show_sysctls() {
    local i val
    for i in "$@" ; do
        val="$(cat "${SYSCTL_BASE}/${i}" 2>/dev/null || echo '?')"
        echo "${i}=${val}"
    done
}

# nat_remove_rules deletes the rules added by nat_apply_rules.
nat_remove_rules() {
    echo "Removing iptables rules..."

    if [ "${OUTGOINGS}" ] ; then
        local int
        nat_parse_outgoings
        for int in "${ints[@]}" ; do
            echo "Removing iptables for outgoing traffics on ${int}..."
            iptables -t nat -D POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -o "${int}" -j MASQUERADE > /dev/null 2>&1 || true
            iptables -D FORWARD -i "${int}" -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            iptables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
        done
    else
        echo "Removing iptables for outgoing traffics on all interfaces..."
        iptables -t nat -D POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -j MASQUERADE > /dev/null 2>&1 || true
        iptables -D FORWARD -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        iptables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
    fi
}
