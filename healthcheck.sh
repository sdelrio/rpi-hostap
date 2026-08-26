#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/client_env.sh
source "${SCRIPT_DIR}/lib/client_env.sh"

# Health check script for rpi-hostap container
# Checks if hostapd, dnsmasq are running and the interface is up

# Configurable start period via environment variable (default: 15s)
START_PERIOD="${HEALTHCHECK_START_PERIOD-15}"
if ! [[ "${START_PERIOD}" =~ ^[0-9]+$ ]]; then
    echo "[Warning] Invalid HEALTHCHECK_START_PERIOD '${START_PERIOD}', using 15" >&2
    START_PERIOD=15
fi

# Grace period is measured from the container's own start time, recorded
# by wlanstart.sh at boot (/proc/uptime reflects HOST uptime in Docker
# and would disable the grace period entirely on long-running hosts).
STARTED_FILE="${HEALTHCHECK_STARTED_FILE:-/run/hostap-started}"
NOW="$(date +%s)"
# When the start-time file is missing (or unreadable), skip the grace
# period and proceed to the real daemon checks instead of treating the
# container as freshly started forever (see issue #219).
if [[ -r "${STARTED_FILE}" ]] && [[ "$(cat "${STARTED_FILE}" 2>/dev/null)" =~ ^-?[0-9]+$ ]]; then
    STARTED="$(cat "${STARTED_FILE}")"
    # During start period, return success to give daemons time to initialize
    if (( NOW - STARTED < START_PERIOD )); then
        exit 0
    fi
else
    echo "[Warning] ${STARTED_FILE} missing or invalid; skipping grace period" >&2
fi

# Check if hostapd is running
if ! pidof hostapd > /dev/null 2>&1; then
    echo "hostapd is not running" >&2
    exit 1
fi

# Check if dnsmasq is running
if ! pidof dnsmasq > /dev/null 2>&1; then
    echo "dnsmasq is not running" >&2
    exit 1
fi

# Check if the wireless interface is up (if INTERFACE is set)
if [[ -n "${INTERFACE:-}" ]]; then
    # Verify the link exists AND is up (state UP), not merely present.
    # Capture output before grepping so grep -q cannot SIGPIPE the producer
    # (which would fail the pipeline under pipefail).
    LINK_STATE="$(ip link show "${INTERFACE}" 2>/dev/null || true)"
    if ! echo "${LINK_STATE}" | grep -q "state UP"; then
        echo "interface ${INTERFACE} is not up" >&2
        exit 1
    fi

    # Check if the AP IP is assigned to the interface (if AP_ADDR is set)
    if [[ -n "${AP_ADDR:-}" ]]; then
        ADDR_OUTPUT="$(ip -4 addr show dev "${INTERFACE}" 2>/dev/null || true)"
        # Anchor the match so e.g. .100 doesn't satisfy a check for .1
        if ! echo "${ADDR_OUTPUT}" | grep -q "inet ${AP_ADDR}/"; then
            echo "address ${AP_ADDR} is not assigned to interface ${INTERFACE}" >&2
            exit 1
        fi
    fi
fi

# Optional deep check: verify the AP is actually beaconing via hostapd_cli.
# Requires HEALTHCHECK_DEEP set (wlanstart.sh then enables ctrl_interface).
# Note: DFS CAC can take 60s+ on radar channels; raise HEALTHCHECK_START_PERIOD
# (e.g. 90) so this check doesn't fail during channel availability scan.
if [[ -n "${HEALTHCHECK_DEEP:-}" ]]; then
    if [[ -z "${INTERFACE:-}" ]]; then
        echo "HEALTHCHECK_DEEP requires INTERFACE to be set" >&2
        exit 1
    fi
    HOSTAPD_STATUS="$(hostapd_cli -p /var/run/hostapd -i "${INTERFACE}" status 2>/dev/null || true)"
    if ! echo "${HOSTAPD_STATUS}" | grep -q "^state=ENABLED"; then
        echo "hostapd is not in ENABLED state" >&2
        exit 1
    fi
fi

# Optional station-count check: fail when fewer than HEALTHCHECK_MIN_STATIONS
# stations are associated. Opt-in (unset = disabled). Requires the control
# interface to exist (enabled via CTRL_INTERFACE or HEALTHCHECK_DEEP).
# Note: on DFS channels stations cannot join until beaconing starts after CAC;
# raise HEALTHCHECK_START_PERIOD accordingly (see docs/healthcheck.md).
MIN_STATIONS="${HEALTHCHECK_MIN_STATIONS-}"
if [[ -n "${MIN_STATIONS}" ]]; then
    if ! [[ "${MIN_STATIONS}" =~ ^[0-9]+$ ]]; then
        echo "[Warning] Invalid HEALTHCHECK_MIN_STATIONS '${MIN_STATIONS}', disabling check" >&2
    elif client_env_resolve_ctrl_iface_dir && [[ -d "${CTRL_IFACE_DIR}" ]]; then
        STATION_COUNT="$(hostapd_cli -p "${CTRL_IFACE_DIR}" -i "${INTERFACE}" all_sta 2>/dev/null \
            | grep -cE '^([0-9a-fA-F]{2}:){5}' || true)"
        if (( STATION_COUNT < MIN_STATIONS )); then
            echo "station count below minimum: expected at least ${MIN_STATIONS}, got ${STATION_COUNT}" >&2
            exit 1
        fi
    fi
fi

exit 0
