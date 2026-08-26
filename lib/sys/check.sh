# shellcheck shell=bash
# shellcheck disable=SC2154
# Read-only runtime state audit used by `wlanstart.sh --check` (issue #288).
#
# Compares live system state against the resolved environment and reports
# each item as OK/FAIL. Never mutates state: only rule existence checks
# (iptables -C), reads of sysctl files and `ip addr/link show` queries.
#
# Requires nat.sh (nat_parse_outgoings) and the resolved env (INTERFACE,
# SUBNET, AP_ADDR, DHCP_PREFIX, OUTGOINGS, IPV6).

IPTABLES_BASE="${IPTABLES_BASE:-iptables}"
IP6TABLES_BASE="${IP6TABLES_BASE:-ip6tables}"
CHECK_IP_BASE="${CHECK_IP_BASE:-${IP_BASE:-ip}}"
CHECK_SYSCTL_BASE="${CHECK_SYSCTL_BASE:-${SYSCTL_BASE:-/proc/sys/net/ipv4}}"

_check_prefix() {
    echo "${SUBNET}/${DHCP_PREFIX:-24}"
}

# _check_item runs the given check command read-only and prints OK/FAIL.
_check_item() {
    local label="$1"
    shift
    if "$@" > /dev/null 2>&1 ; then
        echo "[OK]   ${label}"
    else
        echo "[FAIL] ${label}"
        return 1
    fi
}

_check_masquerade_rule() {
    local int
    if [ "${OUTGOINGS}" ] ; then
        nat_parse_outgoings || return 1
        for int in "${ints[@]}" ; do
            "${IPTABLES_BASE}" -t nat -C POSTROUTING \
                -s "$(_check_prefix)" -o "${int}" -j MASQUERADE 2> /dev/null || return 1
        done
    else
        "${IPTABLES_BASE}" -t nat -C POSTROUTING \
            -s "$(_check_prefix)" -j MASQUERADE 2> /dev/null
    fi
}

_check_forward_rules() {
    local int
    if [ "${OUTGOINGS}" ] ; then
        nat_parse_outgoings || return 1
        for int in "${ints[@]}" ; do
            "${IPTABLES_BASE}" -C FORWARD \
                -i "${int}" -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2> /dev/null || return 1
            "${IPTABLES_BASE}" -C FORWARD \
                -i "${INTERFACE}" -o "${int}" -j ACCEPT 2> /dev/null || return 1
        done
    else
        "${IPTABLES_BASE}" -C FORWARD \
            -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2> /dev/null || return 1
        "${IPTABLES_BASE}" -C FORWARD \
            -i "${INTERFACE}" -j ACCEPT 2> /dev/null
    fi
}

_check_ipv6_rules() {
    local int
    if [ "${OUTGOINGS}" ] ; then
        nat_parse_outgoings || return 1
        for int in "${ints[@]}" ; do
            "${IP6TABLES_BASE}" -C FORWARD \
                -i "${int}" -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2> /dev/null || return 1
            "${IP6TABLES_BASE}" -C FORWARD \
                -i "${INTERFACE}" -o "${int}" -j ACCEPT 2> /dev/null || return 1
        done
    else
        "${IP6TABLES_BASE}" -C FORWARD \
            -o "${INTERFACE}" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2> /dev/null || return 1
        "${IP6TABLES_BASE}" -C FORWARD \
            -i "${INTERFACE}" -j ACCEPT 2> /dev/null
    fi
}

_check_sysctls() {
    local i val
    for i in ip_forward ip_dynaddr ; do
        val="$(cat "${CHECK_SYSCTL_BASE}/${i}" 2>/dev/null)"
        [ "${val}" = "1" ] || return 1
    done
}

_check_interface_addr() {
    "${CHECK_IP_BASE}" link show dev "${INTERFACE}" 2> /dev/null | grep -q '<[^>]*UP' \
        && "${CHECK_IP_BASE}" addr show dev "${INTERFACE}" 2> /dev/null \
            | grep -q " ${AP_ADDR}/${DHCP_PREFIX:-24} "
}

# check_run_audit audits every runtime item, reporting OK/FAIL per item.
# Returns non-zero (after listing all failures) when any check fails.
check_run_audit() {
    local errors=0
    local prefix
    prefix=$(_check_prefix)

    _check_item "MASQUERADE rule for ${prefix}" _check_masquerade_rule || errors=$((errors + 1))
    _check_item "FORWARD rules for ${INTERFACE}" _check_forward_rules || errors=$((errors + 1))
    if [ "${IPV6:-0}" = "1" ] ; then
        _check_item "ip6tables FORWARD rules for ${INTERFACE}" _check_ipv6_rules || errors=$((errors + 1))
    fi
    _check_item "sysctls ip_forward/ip_dynaddr = 1" _check_sysctls || errors=$((errors + 1))
    _check_item "${AP_ADDR}/${DHCP_PREFIX:-24} assigned to ${INTERFACE}, link UP" _check_interface_addr || errors=$((errors + 1))

    if [ "${errors}" -ne 0 ] ; then
        echo "[Error] Check failed with ${errors} failure(s)." >&2
        return 1
    fi
}
