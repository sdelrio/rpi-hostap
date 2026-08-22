#!/bin/bash

# Health check script for rpi-hostap container
# Checks if hostapd, dnsmasq are running and the interface is up

# Configurable start period via environment variable (default: 15s)
START_PERIOD=${HEALTHCHECK_START_PERIOD:-15}

# Get container uptime in seconds
UPTIME_FILE=${HEALTHCHECK_UPTIME_FILE:-/proc/uptime}
UPTIME=$(awk '{print int($1)}' "$UPTIME_FILE")

# During start period, return success to give daemons time to initialize
if [ "$UPTIME" -lt "$START_PERIOD" ]; then
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
    if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
        echo "interface $INTERFACE is not up" >&2
        exit 1
    fi

    # Check if the AP IP is assigned to the interface (if AP_ADDR is set)
    if [ -n "$AP_ADDR" ]; then
        if ! ip -4 addr show dev "$INTERFACE" | grep -q "$AP_ADDR"; then
            echo "address $AP_ADDR is not assigned to interface $INTERFACE" >&2
            exit 1
        fi
    fi
fi

exit 0
