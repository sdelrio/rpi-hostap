# shellcheck shell=bash
# ctrl_interface_compute_conf prints hostapd.conf lines enabling the
# control interface, when CTRL_INTERFACE or HEALTHCHECK_DEEP is set to a
# non-empty value (the deep healthcheck needs it for hostapd_cli).
ctrl_interface_compute_conf() {
    if [ -n "${CTRL_INTERFACE:-}" ] || [ -n "${HEALTHCHECK_DEEP:-}" ] ; then
        echo "ctrl_interface=/var/run/hostapd"
        echo "ctrl_interface_group=0"
    fi
}
