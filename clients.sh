#!/bin/bash

# Client management via hostapd_cli.
#   clients.sh              list all associated stations (all_sta)
#   clients.sh deauth <mac> deauthenticate a station
# Requires CTRL_INTERFACE=1 so hostapd.conf exposes ctrl_interface.
set -euo pipefail

usage() {
    echo "Usage: clients.sh [deauth <mac>]" >&2
}

if [[ -z "${INTERFACE:-}" ]] ; then
    echo "[Error] INTERFACE must be set." >&2
    exit 1
fi

CTRL_IFACE_DIR="${CTRL_IFACE_DIR:-/var/run/hostapd}"

if [[ ! -d "${CTRL_IFACE_DIR}" ]] ; then
    echo "[Error] Control interface not available at ${CTRL_IFACE_DIR}." >&2
    echo "Restart the container with -e CTRL_INTERFACE=1 to enable it." >&2
    exit 1
fi

CMD="${1:-}"

case "${CMD}" in
    "")
        exec hostapd_cli -p "${CTRL_IFACE_DIR}" -i "${INTERFACE}" all_sta
        ;;
    deauth)
        if [[ $# -ne 2 ]] ; then
            usage
            exit 1
        fi
        MAC="${2}"
        if [[ ! "${MAC}" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]] ; then
            echo "[Error] Invalid MAC address '${MAC}' (expected aa:bb:cc:dd:ee:ff)." >&2
            exit 1
        fi
        exec hostapd_cli -p "${CTRL_IFACE_DIR}" -i "${INTERFACE}" deauthenticate "${MAC}"
        ;;
    *)
        usage
        exit 1
        ;;
esac
