# shellcheck shell=bash
# Shared interface bring-up/teardown logic used by wlanstart.sh and tests.

# setup_interface brings the AP interface up and assigns the AP address.
setup_interface() {
    ip link set "${INTERFACE}" up || {
        echo "[Error] Failed to bring up interface ${INTERFACE}" >&2
        return 1
    }
    ip addr flush dev "${INTERFACE}" || {
        echo "[Error] Failed to flush addresses on ${INTERFACE}" >&2
        return 1
    }
    ip addr add "${AP_ADDR}/${DHCP_PREFIX:-24}" dev "${INTERFACE}" || {
        echo "[Error] Failed to assign ${AP_ADDR}/${DHCP_PREFIX:-24} to ${INTERFACE}" >&2
        return 1
    }
}

# teardown_interface removes only the AP address this container configured
# (a blanket `ip addr flush` would wipe unrelated host addresses when running
# with --net host) and brings the link down.
teardown_interface() {
    if [ -n "${INTERFACE}" ] ; then
        echo "Removing ${AP_ADDR}/${DHCP_PREFIX:-24} from interface ${INTERFACE}..."
        ip addr del "${AP_ADDR}/${DHCP_PREFIX:-24}" dev "${INTERFACE}" 2>/dev/null || true
        ip link set "${INTERFACE}" down 2>/dev/null || true
    fi
}
