# shellcheck shell=bash
# Shared WPA configuration logic used by wlanstart.sh and tests.
#
# wpa_compute_conf reads WPA_VERSION (2 | 3 | mixed), HW_MODE and the
# optional PMF variable (0 | 1 | 2) from the environment and writes the
# hostapd wpa_* block to stdout. Messages go to stderr. Returns non-zero
# for invalid values.
#
# PMF (802.11w, ieee80211w): when unset, it is derived from WPA_VERSION
# (2 for WPA3-only, 1 for transition mode, nothing for WPA2). An explicit
# PMF value overrides the derived default, except that PMF=0 is rejected
# as incompatible with WPA_VERSION=3 (WPA3-SAE mandates PMF).
wpa_compute_conf() {
    # Defaults (WPA_VERSION, HW_MODE, WPA_PASSPHRASE) are applied
    # centrally by lib/core/env.sh (issue #237).
    _PMF=""
    case "${WPA_VERSION}" in
        2)
            _WPA_LEVEL="wpa=2"
            _WPA_KEY_MGMT="wpa_key_mgmt=WPA-PSK"
            _WPA_PAIRWISE="# TKIP is no secure anymore
#wpa_pairwise=TKIP CCMP
wpa_pairwise=CCMP
rsn_pairwise=CCMP"
            ;;
        3|mixed)
            if [ "${HW_MODE}" = "b" ] ; then
                echo "[Warning] WPA3/SAE with hw_mode=b (802.11b) is unusual; SAE-capable devices expect g/a." >&2
            fi
            _WPA_LEVEL="wpa=3"
            _WPA_PAIRWISE="rsn_pairwise=CCMP"
            if [ "${WPA_VERSION}" = "3" ] ; then
                echo "[Info] WPA3-SAE enabled. Requires client devices with SAE support (wpa_supplicant 2.7+)." >&2
                _WPA_KEY_MGMT="wpa_key_mgmt=SAE"
                _PMF="ieee80211w=2"
            else
                echo "[Info] WPA2/WPA3 transition mode enabled. Legacy WPA2 clients allowed alongside SAE." >&2
                _WPA_KEY_MGMT="wpa_key_mgmt=WPA-PSK SAE"
                _PMF="ieee80211w=1"
                _WPA_PAIRWISE="wpa_pairwise=CCMP
${_WPA_PAIRWISE}"
            fi
            ;;
        *)
            echo "[Error] Invalid WPA_VERSION '${WPA_VERSION}'. Must be 2 (WPA2-PSK), 3 (WPA3-SAE) or mixed (transition)." >&2
            return 1
            ;;
    esac
    if [ -n "${PMF+x}" ] ; then
        case "${PMF}" in
            0)
                if [ "${WPA_VERSION}" = "3" ] ; then
                    echo "[Error] PMF=0 (disabled) is incompatible with WPA_VERSION=3: WPA3-SAE requires Protected Management Frames." >&2
                    return 1
                fi
                _PMF="ieee80211w=0"
                ;;
            1) _PMF="ieee80211w=1" ;;
            2) _PMF="ieee80211w=2" ;;
            *)
                echo "[Error] Invalid PMF '${PMF}'. Must be 0 (disabled), 1 (optional) or 2 (required)." >&2
                return 1
                ;;
        esac
    fi
    _PMF_LINE=""
    [ -n "${_PMF}" ] && _PMF_LINE="
${_PMF}"
    echo "${_WPA_LEVEL}
wpa_passphrase=${WPA_PASSPHRASE}
${_WPA_KEY_MGMT}${_PMF_LINE}
${_WPA_PAIRWISE}"
}
