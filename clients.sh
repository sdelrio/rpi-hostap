#!/bin/bash

# List stations currently associated with the AP via hostapd_cli.
# Requires CTRL_INTERFACE=1 so hostapd.conf exposes ctrl_interface.
set -euo pipefail

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

exec hostapd_cli -p "${CTRL_IFACE_DIR}" -i "${INTERFACE}" all_sta
