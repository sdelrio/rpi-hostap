# shellcheck shell=bash
# Shared optional MAC address filtering used by wlanstart.sh and tests.
#
# MAC filtering is off by default. When MAC_FILTER is set:
#   1 = allowlist: only MACs listed in MAC_ACL_FILE may associate
#   2 = denylist:  MACs listed in MAC_ACL_FILE are rejected
#
# compute_mac_filter_conf prints the extra hostapd.conf lines (or nothing
# when disabled). Messages go to stderr. Returns non-zero on fatal
# validation errors (filter enabled without a file).

# validate_mac_filter checks the MAC_FILTER/MAC_ACL_FILE combination.
# Returns 1 if the filter is enabled but no file is configured.
validate_mac_filter() {
    case "${MAC_FILTER:-0}" in
        0)
            return 0
            ;;
        1|2)
            if [ -z "${MAC_ACL_FILE}" ] ; then
                echo "[Error] MAC_FILTER=${MAC_FILTER} requires MAC_ACL_FILE to be set." >&2
                return 1
            fi
            if [ ! -r "${MAC_ACL_FILE}" ] ; then
                echo "[Warning] MAC_ACL_FILE '${MAC_ACL_FILE}' is missing or unreadable; hostapd may reject all clients." >&2
            fi
            return 0
            ;;
        *)
            echo "[Error] Invalid MAC_FILTER value '${MAC_FILTER}' (expected 0, 1 or 2)." >&2
            return 1
            ;;
    esac
}

# compute_mac_filter_conf prints hostapd.conf lines for MAC filtering.
compute_mac_filter_conf() {
    case "${MAC_FILTER:-0}" in
        1)
            echo "macaddr_acl=1"
            echo "accept_mac_file=${MAC_ACL_FILE}"
            ;;
        2)
            echo "macaddr_acl=1"
            echo "deny_mac_file=${MAC_ACL_FILE}"
            ;;
        *)
            echo "[Info] MAC_FILTER not enabled, skipping MAC address filtering." >&2
            return 1
            ;;
    esac
}
