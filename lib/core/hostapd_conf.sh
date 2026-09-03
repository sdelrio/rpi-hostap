# shellcheck shell=bash
# hostapd.conf emission (issue #238): pure module, prints the generated
# hostapd.conf to stdout from the current environment. All computation is
# delegated to core compute helpers; no system commands are invoked.

# Emit hostapd.conf to stdout from the current environment.
hostapd_conf_emit() {
    local wpa_conf ap_isolation_conf ssid_hidden_conf mac_filter_conf max_sta_conf ctrl_conf
    wpa_conf=$(wpa_compute_conf) || return 1
    ap_isolation_conf=$(ap_isolation_compute_line)
    ssid_hidden_conf=$(ssid_hidden_compute_line)
    mac_filter_conf=$(mac_filter_compute_conf)
    max_sta_conf=$(stations_compute_max_sta_conf) || return 1
    ctrl_conf=$(ctrl_interface_compute_conf)

    printf '%s\n' \
        "interface=${INTERFACE}" \
        "${DRIVER+"driver=${DRIVER}"}" \
        "ssid=${SSID}" \
        "${ssid_hidden_conf}" \
        "hw_mode=${HW_MODE}" \
        "channel=${CHANNEL}" \
        "${COUNTRY_CODE+"country_code=${COUNTRY_CODE}"}" \
        "${wpa_conf}" \
        "wpa_ptk_rekey=600" \
        "wmm_enabled=1" \
        "${max_sta_conf}" \
        "${ap_isolation_conf}" \
        "${mac_filter_conf}" \
        "${ctrl_conf}" \
        "" \
        "# Activate channel selection for HT High Throughput (802.11an)" \
        "" \
        "${HT_ENABLED+"ieee80211n=1"}" \
        "${HT_CAPAB+"ht_capab=${HT_CAPAB}"}" \
        "" \
        "# Activate channel selection for VHT Very High Throughput (802.11ac)" \
        "" \
        "${VHT_ENABLED+"ieee80211ac=1"}" \
        "${VHT_CAPAB+"vht_capab=${VHT_CAPAB}"}" \
        "" \
        "# Activate channel selection for HE High Efficiency (802.11ax)" \
        "" \
        "${HE_ENABLED+"ieee80211ax=1"}" \
        "${HE_CAPAB+"he_capab=${HE_CAPAB}"}"

    extra_opts_compute_lines
}
