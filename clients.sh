#!/bin/bash

# List stations currently associated with the AP via hostapd_cli.
# Requires CTRL_INTERFACE=1 so hostapd.conf exposes ctrl_interface.
set -euo pipefail

if [ -z "${INTERFACE:-}" ] ; then
    echo "[Error] INTERFACE must be set." >&2
    exit 1
fi

exec hostapd_cli -p "${CTRL_IFACE_DIR:-/var/run/hostapd}" -i "${INTERFACE}" all_sta
