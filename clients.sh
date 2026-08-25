#!/bin/bash

# Client management via hostapd_cli.
#   clients.sh              list all associated stations (all_sta)
#   clients.sh --json       list stations as a JSON array
#   clients.sh deauth <mac> deauthenticate a station
# Requires CTRL_INTERFACE=1 so hostapd.conf exposes ctrl_interface.
set -euo pipefail

usage() {
    echo "Usage: clients.sh [--json] [deauth <mac>]" >&2
}

# Emit a JSON array of station objects parsed from hostapd_cli all_sta output.
# Blocks start with the station MAC line, followed by key=value lines. Only a
# fixed set of well-known fields (aid, signal, connected_time) are exposed as
# strings; values are escaped conservatively.
json_escape() {
    local s="${1}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "${s}"
}

emit_json() {
    local line key value in_obj=0 sep=""
    printf '['
    while IFS= read -r line ; do
        if [[ -z "${line}" ]] ; then
            continue
        fi
        if [[ "${line}" != *=* ]] ; then
            if [[ ${in_obj} -eq 1 ]] ; then
                printf '}'
            fi
            printf '%s{"mac":"%s"' "${sep}" "$(json_escape "${line}")"
            sep=","
            in_obj=1
        else
            key="${line%%=*}"
            value="${line#*=}"
            case "${key}" in
                aid|signal|connected_time)
                    printf ',"%s":"%s"' "${key}" "$(json_escape "${value}")"
                    ;;
            esac
        fi
    done < <(hostapd_cli -p "${CTRL_IFACE_DIR}" -i "${INTERFACE}" all_sta)
    [[ ${in_obj} -eq 1 ]] && printf '}'
    printf ']\n'
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
    --json)
        emit_json
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
