#!/bin/bash

# Health check script for rpi-hostap container
# Checks if hostapd, dnsmasq are running and the interface is up

# Configurable start period via environment variable (default: 15s)
START_PERIOD=${HEALTHCHECK_START_PERIOD:-15}

# Grace period is measured from the container's own start time, recorded
# by wlanstart.sh at boot (/proc/uptime reflects HOST uptime in Docker
# and would disable the grace period entirely on long-running hosts).
STARTED_FILE=${HEALTHCHECK_STARTED_FILE:-/run/hostap-started}
NOW=$(date +%s)
STARTED=$(cat "$STARTED_FILE" 2>/dev/null || echo "$NOW")

# During start period, return success to give daemons time to initialize
if [ $((NOW - STARTED)) -lt "$START_PERIOD" ]; then
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
if [ -n "$INTERFACE" ]; then
    # Verify the link exists AND is up (state UP), not merely present
    if ! ip link show "$INTERFACE" 2>/dev/null | grep -q "state UP"; then
        echo "interface $INTERFACE is not up" >&2
        exit 1
    fi

    # Check if the AP IP is assigned to the interface (if AP_ADDR is set)
    if [ -n "$AP_ADDR" ]; then
        # Anchor the match so e.g. .100 doesn't satisfy a check for .1
        if ! ip -4 addr show dev "$INTERFACE" | grep -q "inet ${AP_ADDR}/"; then
            echo "address $AP_ADDR is not assigned to interface $INTERFACE" >&2
            exit 1
        fi
    fi
fi

exit 0
