# compute_ctrl_interface_conf prints hostapd.conf lines enabling the
# control interface, only when CTRL_INTERFACE is set to a non-empty value.
compute_ctrl_interface_conf() {
    if [ -n "${CTRL_INTERFACE:-}" ] ; then
        echo "ctrl_interface=/var/run/hostapd"
        echo "ctrl_interface_group=0"
    fi
}
