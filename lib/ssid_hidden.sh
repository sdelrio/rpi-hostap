# shellcheck shell=bash
# Shared hidden SSID logic used by wlanstart.sh and tests.
#
# compute_ssid_hidden_line reads HIDE_SSID from the environment and
# prints the hostapd `ssid_hidden=` config line, or nothing if the
# variable is unset.
compute_ssid_hidden_line() {
    echo "${HIDE_SSID+"ssid_hidden=${HIDE_SSID}"}"
}
