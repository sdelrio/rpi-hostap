# shellcheck shell=bash
# Shared IPv4 NAT logic used by wlanstart.sh and tests.
#
# parse_outgoings fills ints with the comma-separated OUTGOINGS interfaces.

parse_outgoings() {
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

# interface_exists returns 0 when the given network interface exists.
interface_exists() {
    "${IP_BASE}" link show "$1" > /dev/null 2>&1
}

# validate_outgoings checks every parsed OUTGOINGS interface exists,
# failing fast with an error naming the offending interface.
validate_outgoings() {
    local int
    parse_outgoings
    for int in "${ints[@]}" ; do
        if ! interface_exists "${int}" ; then
            echo "[Error] OUTGOINGS interface '${int}' does not exist" >&2
            return 1
        fi
    done
}

# apply_nat_rules adds iptables MASQUERADE/FORWARD rules for outgoing traffic.
apply_nat_rules() {
    if [ "${OUTGOINGS}" ] ; then
        local int
        validate_outgoings || return 1
        for int in "${ints[@]}"
        do
            echo "Setting iptables for outgoing traffics on ${int}..."

            iptables -t nat -D POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -o "${int}" -j MASQUERADE > /dev/null 2>&1 || true
            iptables -t nat -A POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -o "${int}" -j MASQUERADE

            iptables -D FORWARD -i "${int}" -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            iptables -A FORWARD -i "${int}" -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT

            iptables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
            iptables -A FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT
        done
    else
        echo "Setting iptables for outgoing traffics on all interfaces..."

        iptables -t nat -D POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -j MASQUERADE > /dev/null 2>&1 || true
        iptables -t nat -A POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -j MASQUERADE

        iptables -D FORWARD -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        iptables -A FORWARD -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT

        iptables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
        iptables -A FORWARD -i "${INTERFACE}" -j ACCEPT
    fi
}

# set_sysctls enables the given ipv4 sysctls, tolerating missing entries
# (e.g. kernels built without ip_dynaddr). SYSCTL_BASE can be overridden
# in tests to point at a stubbed procfs tree.
SYSCTL_BASE="${SYSCTL_BASE:-/proc/sys/net/ipv4}"

set_sysctls() {
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

# show_sysctls prints labeled values for the given ipv4 sysctls (#194).
show_sysctls() {
    local i val
    for i in "$@" ; do
        val="$(cat "${SYSCTL_BASE}/${i}" 2>/dev/null || echo '?')"
        echo "${i}=${val}"
    done
}

# remove_nat_rules deletes the rules added by apply_nat_rules.
remove_nat_rules() {
    echo "Removing iptables rules..."

    if [ "${OUTGOINGS}" ] ; then
        local int
        parse_outgoings
        for int in "${ints[@]}" ; do
            echo "Removing iptables for outgoing traffics on ${int}..."
            iptables -t nat -D POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -o "${int}" -j MASQUERADE > /dev/null 2>&1 || true
            iptables -D FORWARD -i "${int}" -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            iptables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
        done
    else
        echo "Removing iptables for outgoing traffics on all interfaces..."
        iptables -t nat -D POSTROUTING -s "${SUBNET}/${DHCP_PREFIX:-24}" -j MASQUERADE > /dev/null 2>&1 || true
        iptables -D FORWARD -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        iptables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
    fi
}
