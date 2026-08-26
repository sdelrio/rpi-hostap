# shellcheck shell=bash
# Shared env plumbing for scripts driving hostapd_cli (clients.sh,
# healthcheck.sh). Issue #243: single implementation of INTERFACE /
# CTRL_IFACE_DIR handling so behavior and error messages stay identical.

# Fail with the canonical error when INTERFACE is unset or empty.
client_env_require_interface() {
    if [[ -z "${INTERFACE:-}" ]] ; then
        echo "[Error] INTERFACE must be set." >&2
        exit 1
    fi
}

# Apply the default control-interface directory when CTRL_IFACE_DIR is unset.
client_env_resolve_ctrl_iface_dir() {
    CTRL_IFACE_DIR="${CTRL_IFACE_DIR:-/var/run/hostapd}"
}

# Fail when the resolved control interface directory does not exist.
client_env_require_ctrl_interface() {
    client_env_resolve_ctrl_iface_dir
    if [[ ! -d "${CTRL_IFACE_DIR}" ]] ; then
        echo "[Error] Control interface not available at ${CTRL_IFACE_DIR}." >&2
        echo "Restart the container with -e CTRL_INTERFACE=1 to enable it." >&2
        exit 1
    fi
}
