# shellcheck shell=bash
# Shared channel/hw_mode/country validation logic used by wlanstart.sh and tests.
#
# channel_validate reads HW_MODE, CHANNEL and COUNTRY_CODE from the
# environment (defaults applied centrally by lib/core/env.sh, see issue
# #237) and returns non-zero when the channel is not allowed.
# Messages go to stderr.
channel_to_upper() {
    local _result='' _i _ch
    for (( _i=0; _i<${#1}; _i++ )); do
        _ch="${1:_i:1}"
        case "${_ch}" in
            a) _ch=A ;; b) _ch=B ;; c) _ch=C ;; d) _ch=D ;; e) _ch=E ;;
            f) _ch=F ;; g) _ch=G ;; h) _ch=H ;; i) _ch=I ;; j) _ch=J ;;
            k) _ch=K ;; l) _ch=L ;; m) _ch=M ;; n) _ch=N ;; o) _ch=O ;;
            p) _ch=P ;; q) _ch=Q ;; r) _ch=R ;; s) _ch=S ;; t) _ch=T ;;
            u) _ch=U ;; v) _ch=V ;; w) _ch=W ;; x) _ch=X ;; y) _ch=Y ;;
            z) _ch=Z ;;
        esac
        _result+="${_ch}"
    done
    printf '%s' "${_result}"
}

channel_to_lower() {
    local _result='' _i _ch
    for (( _i=0; _i<${#1}; _i++ )); do
        _ch="${1:_i:1}"
        case "${_ch}" in
            A) _ch=a ;; B) _ch=b ;; C) _ch=c ;; D) _ch=d ;; E) _ch=e ;;
            F) _ch=f ;; G) _ch=g ;; H) _ch=h ;; I) _ch=i ;; J) _ch=j ;;
            K) _ch=k ;; L) _ch=l ;; M) _ch=m ;; N) _ch=n ;; O) _ch=o ;;
            P) _ch=p ;; Q) _ch=q ;; R) _ch=r ;; S) _ch=s ;; T) _ch=t ;;
            U) _ch=u ;; V) _ch=v ;; W) _ch=w ;; X) _ch=x ;; Y) _ch=y ;;
            Z) _ch=z ;;
        esac
        _result+="${_ch}"
    done
    printf '%s' "${_result}"
}

channel_validate() {
    # Normalize case so lowercase country codes and uppercase hw_mode
    # values are validated correctly instead of falling through (issue #222).
    COUNTRY_CODE="$(channel_to_upper "${COUNTRY_CODE:-}")"
    HW_MODE="$(channel_to_lower "${HW_MODE:-}")"

    # Automatic channel selection: skip numeric checks, driver decides.
    case "${HW_MODE}:${CHANNEL}" in
        *:[aA][cC][sS])
            if [ "${_channel_ACS_WARNED:-0}" -eq 0 ]; then
                echo "[Warning] CHANNEL=acs enables automatic channel selection; requires driver support and may delay startup" >&2
                echo "[Warning] ACS may select a DFS/radar channel; the HEALTHCHECK_START_PERIOD grace period applies while CAC completes" >&2
                _channel_ACS_WARNED=1
            fi
            return 0
            ;;
    esac

    # Channel 14 is legal in Japan only for 802.11b.
    if [ "${CHANNEL}" = "14" ]; then
        if [ "${COUNTRY_CODE}" = "JP" ] && [ "${HW_MODE}" = "b" ]; then
            return 0
        fi
        echo "[Error] Channel 14 is only allowed in Japan (COUNTRY_CODE=JP) with hw_mode=b (802.11b)" >&2
        return 1
    fi

    case "${COUNTRY_CODE}" in
        US|CA|MX) _channel_MAX_CHANNEL=11 ;;
        JP)       _channel_MAX_CHANNEL=14 ;;
        *)        _channel_MAX_CHANNEL=13 ;;  # fallback: Europe (ETSI)
    esac

    case "${HW_MODE}" in
        g|b)
            if ! [ "${CHANNEL}" -gt 0 ] 2>/dev/null; then
                echo "[Error] Channel '${CHANNEL}' must be a positive integer" >&2
                return 1
            fi
            if [ "${CHANNEL}" -gt "${_channel_MAX_CHANNEL}" ] 2>/dev/null; then
                echo "[Error] Channel ${CHANNEL} not allowed for country ${COUNTRY_CODE} (max ${_channel_MAX_CHANNEL} for hw_mode=${HW_MODE})" >&2
                return 1
            fi
            ;;
        a)
            if ! [ "${CHANNEL}" -gt 0 ] 2>/dev/null; then
                echo "[Error] Channel '${CHANNEL}' must be a positive integer" >&2
                return 1
            fi
            case "${CHANNEL}" in
                36|40|44|48)
                    ;;
                149|153|157|161|165)
                    # U-NII-3 high band is not legal in ETSI regions; only
                    # allow it for countries where it is permitted (issue #221).
                    case "${COUNTRY_CODE}" in
                        US|CA|MX|JP) ;;
                        *)
                            echo "[Error] Channel ${CHANNEL} not allowed for country ${COUNTRY_CODE} (channels 149-165 require US/CA/MX/JP)" >&2
                            return 1
                            ;;
                    esac
                    ;;
                52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|144)
                    if [ "${_channel_DFS_WARNED:-0}" -eq 0 ]; then
                        echo "[Warning] Channel ${CHANNEL} is a DFS channel (radar detection/CAC required), may not work on all drivers" >&2
                        _channel_DFS_WARNED=1
                    fi
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

# VHT (802.11ac) requires 5 GHz operation.
# Reads VHT_ENABLED and HW_MODE from the environment.
channel_validate_vht() {
    HW_MODE="$(channel_to_lower "${HW_MODE:-}")"
    if [ -n "${VHT_ENABLED:-}" ] && [ "${HW_MODE}" != "a" ] ; then
        echo "[Error] VHT_ENABLED requires HW_MODE=a (5 GHz)." >&2
        return 1
    fi
    return 0
}

# HE (802.11ax) requires 5 GHz operation, same band rules as VHT.
# Reads HE_ENABLED and HW_MODE from the environment.
channel_validate_he() {
    HW_MODE="$(channel_to_lower "${HW_MODE:-}")"
    if [ -n "${HE_ENABLED:-}" ] && [ "${HW_MODE}" != "a" ] ; then
        echo "[Error] HE_ENABLED requires HW_MODE=a (5 GHz)." >&2
        return 1
    fi
    return 0
}

# Strict variant used by validation mode: unknown HW_MODE is an error.
channel_validate_strict() {
    if ! channel_validate ; then
        return 1
    fi
    case "${HW_MODE}" in
        a|b|g) ;;
        *)
            echo "[Error] Unknown hw_mode='${HW_MODE}' (allowed: b, g, a)" >&2
            return 1
            ;;
    esac
    return 0
}
