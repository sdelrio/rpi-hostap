# shellcheck shell=bash
# Shared WPA configuration logic used by wlanstart.sh and tests.
#
# compute_wpa_conf reads WPA_VERSION (2 | 3 | mixed) and HW_MODE from the
# environment and writes the hostapd wpa_* block to stdout. Messages go to
# stderr. Returns non-zero for invalid WPA_VERSION values.
compute_wpa_conf() {
    # Defaults (WPA_VERSION, HW_MODE, WPA_PASSPHRASE) are applied
    # centrally by lib/env.sh (issue #237).
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
    _PMF_LINE=""
    [ -n "${_PMF}" ] && _PMF_LINE="
${_PMF}"
    echo "${_WPA_LEVEL}
wpa_passphrase=${WPA_PASSPHRASE}
${_WPA_KEY_MGMT}${_PMF_LINE}
${_WPA_PAIRWISE}"
}
