# shellcheck shell=bash
# Shared channel/hw_mode/country validation logic used by wlanstart.sh and tests.
#
# validate_channel reads HW_MODE, CHANNEL and COUNTRY_CODE from the
# environment (applying the same defaults as wlanstart.sh) and returns
# non-zero when the channel is not allowed. Messages go to stderr.
validate_channel() {
    : "${HW_MODE:=g}"
    : "${CHANNEL:=11}"
    : "${COUNTRY_CODE:=EU}"

    case "${COUNTRY_CODE}" in
        US|CA|MX) _MAX_CHANNEL=11 ;;
        JP)       _MAX_CHANNEL=14 ;;
        *)        _MAX_CHANNEL=13 ;;  # fallback: Europe (ETSI)
    esac

    case "${HW_MODE}" in
        g|b)
            if ! [ "${CHANNEL}" -gt 0 ] 2>/dev/null; then
                echo "[Error] Channel '${CHANNEL}' must be a positive integer" >&2
                return 1
            fi
            if [ "${CHANNEL}" -gt "${_MAX_CHANNEL}" ] 2>/dev/null; then
                echo "[Error] Channel ${CHANNEL} not allowed for country ${COUNTRY_CODE} (max ${_MAX_CHANNEL} for hw_mode=${HW_MODE})" >&2
                return 1
            fi
            ;;
        a)
            if ! [ "${CHANNEL}" -gt 0 ] 2>/dev/null; then
                echo "[Error] Channel '${CHANNEL}' must be a positive integer" >&2
                return 1
            fi
            case "${CHANNEL}" in
                36|40|44|48|149|153|157|161|165)
                    ;;
                52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|144)
                    echo "[Warning] Channel ${CHANNEL} is a DFS channel (radar detection/CAC required), may not work on all drivers" >&2
                    ;;
                *)
                    echo "[Error] Channel ${CHANNEL} not allowed for hw_mode=a (allowed: 36,40,44,48,149,153,157,161,165; DFS: 52-144)" >&2
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "[Warning] Unknown hw_mode='${HW_MODE}', skipping channel validation" >&2
            ;;
    esac
    return 0
}
