#!/bin/bash
set -euo pipefail

# Health check script for rpi-hostap container
# Checks if hostapd, dnsmasq are running and the interface is up

# Configurable start period via environment variable (default: 15s)
START_PERIOD="${HEALTHCHECK_START_PERIOD:-15}"

# Grace period is measured from the container's own start time, recorded
# by wlanstart.sh at boot (/proc/uptime reflects HOST uptime in Docker
# and would disable the grace period entirely on long-running hosts).
STARTED_FILE="${HEALTHCHECK_STARTED_FILE:-/run/hostap-started}"
NOW="$(date +%s)"
STARTED="$(cat "${STARTED_FILE}" 2>/dev/null || echo "${NOW}")"

# During start period, return success to give daemons time to initialize
if (( NOW - STARTED < START_PERIOD )); then
    exit 0
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
    HOSTAPD_STATUS="$(hostapd_cli -p /var/run/hostapd -i "${INTERFACE}" status 2>/dev/null || true)"
    if ! echo "${HOSTAPD_STATUS}" | grep -q "^state=ENABLED"; then
        echo "hostapd is not in ENABLED state" >&2
        exit 1
    fi
fi

exit 0
