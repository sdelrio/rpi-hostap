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
            if [ "${CHANNEL}" -le 14 ] 2>/dev/null; then
                echo "[Warning] Channel ${CHANNEL} may be invalid for hw_mode=a (5GHz typically > 14)" >&2
            fi
            ;;
        *)
            echo "[Warning] Unknown hw_mode='${HW_MODE}', skipping channel validation" >&2
            ;;
    esac
    return 0
}
