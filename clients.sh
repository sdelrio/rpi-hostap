#!/bin/bash

# Client management via hostapd_cli.
#   clients.sh              list all associated stations (all_sta)
#   clients.sh --json       list stations as a JSON array
#   clients.sh count        print the number of associated stations
#   clients.sh deauth <mac> deauthenticate a station
#   clients.sh leases       show dnsmasq DHCP leases
# Requires CTRL_INTERFACE=1 so hostapd.conf exposes ctrl_interface.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Declarative module loading (issue #239)
# shellcheck source=lib/bootstrap.sh
source "${SCRIPT_DIR}/lib/bootstrap.sh"
require_module client_env

clients_show_usage() {
    echo "Usage: clients.sh [--json] [count] [deauth <mac>] [leases [--json]]" >&2
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

# Resolve the dnsmasq lease file path (overridable for tests).
_clients_lease_file() {
    echo "${DHCP_LEASE_FILE:-/tmp/dnsmasq.leases}"
}

# Fail with a canonical error when the lease file is absent.
_clients_lease_file_require() {
    local file
    file=$(_clients_lease_file)
    if [[ ! -f "${file}" ]] ; then
        echo "[Error] Lease file not found at ${file}." >&2
        exit 1
    fi
}

# Print raw dnsmasq lease lines: expires_remaining mac ip hostname clientid
clients_leases_show() {
    _clients_lease_file_require
    cat "$(_clients_lease_file)"
}

# Emit a JSON array of {mac, ip, hostname, expires} objects parsed from the
# dnsmasq lease file (fields: expires_remaining mac ip hostname clientid).
clients_emit_leases_json() {
    local line mac ip hostname expires sep=""
    _clients_lease_file_require
    printf '['
    while IFS= read -r line ; do
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        read -r expires mac ip hostname _ <<<"${line}"
        [[ -z "${mac:-}" ]] && continue
        printf '%s{"mac":"%s","ip":"%s","hostname":"%s","expires":"%s"}' \
            "${sep}" \
            "$(clients_json_escape "${mac}")" \
            "$(clients_json_escape "${ip}")" \
            "$(clients_json_escape "${hostname}")" \
            "$(clients_json_escape "${expires}")"
        sep=","
    done < <(cat "$(_clients_lease_file)")
    printf ']\n'
}



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
    leases)
        shift
        if [[ "${1:-}" == "--json" ]] ; then
            [[ $# -eq 1 ]] || { clients_show_usage ; exit 1 ; }
            clients_emit_leases_json
        elif [[ $# -eq 0 ]] ; then
            clients_leases_show
        else
            clients_show_usage
            exit 1
        fi
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
