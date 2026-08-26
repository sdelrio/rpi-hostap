#!/bin/bash

# Client management via hostapd_cli.
#   clients.sh              list all associated stations (all_sta)
#   clients.sh --json       list stations as a JSON array
#   clients.sh count        print the number of associated stations
#   clients.sh deauth <mac> deauthenticate a station
# Requires CTRL_INTERFACE=1 so hostapd.conf exposes ctrl_interface.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/core/client_env.sh
source "${SCRIPT_DIR}/lib/core/client_env.sh"

clients_show_usage() {
    echo "Usage: clients.sh [--json] [count] [deauth <mac>]" >&2
}

# Emit a JSON array of station objects parsed from hostapd_cli all_sta output.
# Blocks start with the station MAC line, followed by key=value lines. Only a
# fixed set of well-known fields (aid, signal, connected_time) are exposed as
# strings; values are escaped conservatively.
clients_json_escape() {
    local s="${1}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "${s}"
}

clients_emit_json() {
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
            printf '%s{"mac":"%s"' "${sep}" "$(clients_json_escape "${line}")"
            sep=","
            in_obj=1
        else
            key="${line%%=*}"
            value="${line#*=}"
            case "${key}" in
                aid|signal|connected_time)
                    printf ',"%s":"%s"' "${key}" "$(clients_json_escape "${value}")"
                    ;;
            esac
        fi
    done < <(hostapd_cli -p "${CTRL_IFACE_DIR}" -i "${INTERFACE}" all_sta)
    [[ ${in_obj} -eq 1 ]] && printf '}'
    printf ']\n'
}

# Count associated stations: number of MAC-address lines in all_sta output
# (same parsing pattern as clients_emit_json, which treats non-key=value lines as
# station blocks starting with the MAC).
clients_count_stations() {
    hostapd_cli -p "${CTRL_IFACE_DIR}" -i "${INTERFACE}" all_sta \
        | grep -cE '^([0-9a-fA-F]{2}:){5}' || true
}

client_env_require_interface
client_env_require_ctrl_interface

CMD="${1:-}"

case "${CMD}" in
    "")
        exec hostapd_cli -p "${CTRL_IFACE_DIR}" -i "${INTERFACE}" all_sta
        ;;
    --json)
        clients_emit_json
        ;;
    count)
        clients_count_stations
        ;;
    deauth)
        if [[ $# -ne 2 ]] ; then
            clients_show_usage
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
        clients_show_usage
        exit 1
        ;;
esac
