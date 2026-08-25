# shellcheck shell=bash
# Shared TX_POWER (transmit power) logic used by wlanstart.sh and tests.
#
# TX_POWER is optional: unset means leave the driver default. "auto"
# restores driver/regulatory automatic power control; a positive integer
# sets a fixed transmit power in dBm via `iw dev <iface> set txpower`.
# The value must respect the regulatory limits of COUNTRY_CODE - iw will
# reject powers above the allowed EIRP for the configured domain.
#
# validate_tx_power checks the value without touching the system
# (used by --validate mode and before any system change).
validate_tx_power() {
    [ -z "${TX_POWER:-}" ] && return 0
    case "${TX_POWER}" in
        auto) return 0 ;;
        ""|*[!0-9]*)
            echo "[Error] Invalid TX_POWER '${TX_POWER}'. Must be 'auto' or an integer power in dBm." >&2
            return 1
            ;;
    esac
    return 0
}

# apply_tx_power applies TX_POWER to INTERFACE via iw. Fails fatally when
# iw rejects the value: the operator asked explicitly for a power cap,
# silently running at full power would violate that intent.
apply_tx_power() {
    [ -n "${TX_POWER:-}" ] || return 0
    if ! command -v iw >/dev/null 2>&1 ; then
        echo "[Error] TX_POWER set but 'iw' is not available on ${INTERFACE}" >&2
        return 1
    fi
    case "${TX_POWER}" in
        auto)
            iw dev "${INTERFACE}" set txpower auto
            ;;
        *)
            iw dev "${INTERFACE}" set txpower fixed "${TX_POWER}"
            ;;
    esac || {
        echo "[Error] Failed to set txpower ${TX_POWER} on ${INTERFACE}. Check the value against your COUNTRY_CODE=${COUNTRY_CODE} regulatory limits." >&2
        return 1
    }
}
