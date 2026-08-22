# shellcheck shell=bash
# Shared AP isolation logic used by wlanstart.sh and tests.
#
# compute_ap_isolation_line reads AP_ISOLATION from the environment and
# prints the hostapd `ap_isolate=` config line, or nothing if the variable
# is unset.
compute_ap_isolation_line() {
    echo "${AP_ISOLATION+"ap_isolate=${AP_ISOLATION}"}"
}
