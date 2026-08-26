# shellcheck shell=bash
# Shared interface bring-up/teardown logic used by wlanstart.sh and tests.

# Teardown hook registration for the phase-based lifecycle (issue #241).
# Interface is registered last: teardown runs in reverse-dependency order
# (nat -> ipv6 -> interface), so the interface goes down after the rules
# that reference it have been removed.
PHASE_TEARDOWN+=("interface_teardown")

# interface_setup brings the AP interface up and assigns the AP address.
interface_setup() {
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

# interface_teardown removes only the AP address this container configured
# (a blanket `ip addr flush` would wipe unrelated host addresses when running
# with --net host) and brings the link down.
interface_teardown() {
    if [ -n "${INTERFACE}" ] ; then
        echo "Removing ${AP_ADDR}/${DHCP_PREFIX:-24} from interface ${INTERFACE}..."
        ip addr del "${AP_ADDR}/${DHCP_PREFIX:-24}" dev "${INTERFACE}" 2>/dev/null || true
        ip link set "${INTERFACE}" down 2>/dev/null || true
    fi
}
