#!/bin/bash

# NAT and interface logic lives in lib/nat.sh and lib/interface.sh,
# shared with tests
# shellcheck source=lib/nat.sh
. "$(dirname "$0")/lib/nat.sh"
# shellcheck source=lib/interface.sh
. "$(dirname "$0")/lib/interface.sh"

cleanup() {
    echo "Shutting down..."

    remove_nat_rules

    if [ "${IPV6:-0}" = "1" ] ; then
        echo "Removing ip6tables rules..."
        remove_ipv6_rules
    fi

    teardown_interface
}

# multirun manages hostapd/dnsmasq and exits when any child dies.
# On SIGINT/SIGTERM we forward the signal to multirun, which relays it
# to all children; teardown runs once multirun has exited.
_MULTIRUN_PID=""
_SIGNALED=0

# Invoked indirectly via trap
# shellcheck disable=SC2329,SC2317
handle_signal() {
    _SIGNALED=1
    if [ -n "${_MULTIRUN_PID}" ] ; then
        kill "${_MULTIRUN_PID}" 2>/dev/null || true
    fi
}

# Exit promptly when a signal arrives before multirun is launched
check_interrupted() {
    if [ "${_SIGNALED}" = "1" ] ; then
        echo "[Info] Shutdown requested during startup." >&2
        cleanup
        exit 0
    fi
}

trap handle_signal SIGINT SIGTERM SIGHUP

# Record container start time so healthcheck.sh can measure the grace
# period from the actual start (not host uptime via /proc/uptime).
date +%s > /run/hostap-started 2>/dev/null || true

# Check if running in privileged mode
if [ ! -w "/sys" ] ; then
    echo "[Error] Not running in privileged mode."
    exit 1
fi

# Check environment variables
if [ ! "${INTERFACE}" ] ; then
    echo "[Error] An interface must be specified."
    exit 1
fi

# Set HW_MODE and CHANNEL early for validation
: "${HW_MODE:=g}"
: "${CHANNEL:=11}"

# Warn if COUNTRY_CODE was not explicitly set, then default to EU (ETSI)
if [ -z "${COUNTRY_CODE+x}" ] ; then
    echo "[Warning] COUNTRY_CODE not set, defaulting to 'EU' (ETSI: channels 1-13)."
    echo "          Set COUNTRY_CODE (e.g. US, CA, JP) to match your local regulations."
fi
: "${COUNTRY_CODE:=EU}"

# Validate channel against regulatory domain and hardware mode
# Logic lives in lib/channel.sh, shared with tests
# shellcheck source=lib/channel.sh
. "$(dirname "$0")/lib/channel.sh"
if ! validate_channel ; then
    exit 1
fi

# Default values
: "${SUBNET:=192.168.254.0}"
: "${AP_ADDR:=192.168.254.1}"
: "${PRI_DNS:=8.8.8.8}"
: "${SEC_DNS:=8.8.4.4}"
: "${SSID:=raspberry}"
: "${WPA_PASSPHRASE:=passw0rd}"
: "${MAX_STATIONS:=0}"

# Validate AP_ADDR and SUBNET are well-formed IPv4 addresses before
# touching the system.
# Logic lives in lib/validation.sh, shared with tests
# shellcheck source=lib/validation.sh
. "$(dirname "$0")/lib/validation.sh"
if ! validate_ipv4 "${SUBNET}" ; then
    echo "[Error] Invalid SUBNET: '${SUBNET}' is not a valid IPv4 address." >&2
    exit 1
fi
if ! validate_ipv4 "${AP_ADDR}" ; then
    echo "[Error] Invalid AP_ADDR: '${AP_ADDR}' is not a valid IPv4 address." >&2
    exit 1
fi

# Startup warnings for default credentials
# Logic lives in lib/warnings.sh, shared with tests
# shellcheck source=lib/warnings.sh
. "$(dirname "$0")/lib/warnings.sh"
emit_credential_warnings
# Validate WPA_PASSPHRASE length (8-63 chars required by WPA-PSK/SAE)
# Logic lives in lib/passphrase.sh, shared with tests
# shellcheck source=lib/passphrase.sh
. "$(dirname "$0")/lib/passphrase.sh"
if ! validate_passphrase ; then
    exit 1
fi
check_interrupted

# MAX_STATIONS: limit number of associated stations (0 = unlimited)
# Logic lives in lib/stations.sh, shared with tests
# shellcheck source=lib/stations.sh
. "$(dirname "$0")/lib/stations.sh"

# WPA version: 2 (WPA2-PSK, default), 3 (WPA3-SAE) or mixed (WPA2/WPA3 transition)
# Logic lives in lib/wpa.sh, shared with tests
# shellcheck source=lib/wpa.sh
. "$(dirname "$0")/lib/wpa.sh"
if ! _WPA_CONF=$(compute_wpa_conf) ; then
    exit 1
fi

# AP isolation: emit ap_isolate= only when AP_ISOLATION is set
# Logic lives in lib/ap_isolation.sh, shared with tests
# shellcheck source=lib/ap_isolation.sh
. "$(dirname "$0")/lib/ap_isolation.sh"
_AP_ISOLATION_CONF=$(compute_ap_isolation_line)

# Hidden SSID: emit ssid_hidden= only when HIDE_SSID is set
# Logic lives in lib/ssid_hidden.sh, shared with tests
# shellcheck source=lib/ssid_hidden.sh
. "$(dirname "$0")/lib/ssid_hidden.sh"
_SSID_HIDDEN_CONF=$(compute_ssid_hidden_line)

# MAC address filtering (off by default, enable with MAC_FILTER=1 or 2)
# Logic lives in lib/mac_filter.sh, shared with tests
# shellcheck source=lib/mac_filter.sh
. "$(dirname "$0")/lib/mac_filter.sh"
if ! validate_mac_filter ; then
    exit 1
fi
_MAC_FILTER_CONF=$(compute_mac_filter_conf)

_MAX_STA_CONF=$(compute_max_sta_conf)

# Control interface: opt-in via CTRL_INTERFACE (any non-empty value)
# Logic lives in lib/ctrl_interface.sh, shared with tests
# shellcheck source=lib/ctrl_interface.sh
. "$(dirname "$0")/lib/ctrl_interface.sh"
_CTRL_INTERFACE_CONF=$(compute_ctrl_interface_conf)

# Always regenerate hostapd.conf so env var changes apply between runs
cat > "/etc/hostapd.conf" <<EOF
interface=${INTERFACE}
${DRIVER+"driver=${DRIVER}"}
ssid=${SSID}
${_SSID_HIDDEN_CONF}
hw_mode=${HW_MODE}
channel=${CHANNEL}
${COUNTRY_CODE+"country_code=${COUNTRY_CODE}"}
${_WPA_CONF}
wpa_ptk_rekey=600
wmm_enabled=1
${_MAX_STA_CONF}
${_AP_ISOLATION_CONF}
${_MAC_FILTER_CONF}
${_CTRL_INTERFACE_CONF}

# Activate channel selection for HT High Throughput (802.11an)

${HT_ENABLED+"ieee80211n=1"}
${HT_CAPAB+"ht_capab=${HT_CAPAB}"}

# Activate channel selection for VHT Very High Throughput (802.11ac)

${VHT_ENABLED+"ieee80211ac=1"}
${VHT_CAPAB+"vht_capab=${VHT_CAPAB}"}
EOF
check_interrupted

# Setup interface and restart DHCP service
if ! setup_interface ; then
    exit 1
fi
check_interrupted

# NAT settings
echo "NAT settings ip_dynaddr, ip_forward"


for i in ip_dynaddr ip_forward ; do
  if [ "$(cat "/proc/sys/net/ipv4/${i}")" -eq 1 ] ; then
    echo "${i}" already 1
  else
    echo "1" > "/proc/sys/net/ipv4/${i}"
  fi
done

cat /proc/sys/net/ipv4/ip_dynaddr
cat /proc/sys/net/ipv4/ip_forward

apply_nat_rules

# Optional IPv6 support (off by default, enable with IPV6=1)
# Logic lives in lib/ipv6.sh, shared with tests
# shellcheck source=lib/ipv6.sh
. "$(dirname "$0")/lib/ipv6.sh"

_IPV6_CONF=""
if [ "${IPV6:-0}" = "1" ] ; then
    echo "Enabling IPv6 forwarding..."
    enable_ipv6_forwarding
    echo "Setting ip6tables rules for outgoing traffics..."
    apply_ipv6_rules
fi

echo "Configuring DHCP server .."

# Logic lives in lib/dhcp.sh, shared with tests
# shellcheck source=lib/dhcp.sh
. "$(dirname "$0")/lib/dhcp.sh"

DHCP_RANGE=$(compute_dhcp_range) || exit 1

if [ "${IPV6:-0}" = "1" ] ; then
    _IPV6_CONF=$(compute_dnsmasq_ipv6_conf)
fi

cat > "/etc/dnsmasq.conf" <<EOF
interface=${INTERFACE}
dhcp-range=${DHCP_RANGE}
dhcp-option=option:router,${AP_ADDR}
dhcp-option=option:dns-server,${PRI_DNS},${SEC_DNS}
${_IPV6_CONF}
EOF

echo "Starting dnsmasq and hostapd via multirun ..."
check_interrupted
# Tag each daemon's output so failures are attributable (issue #119).
# NOTE: multirun already wraps each command in `exec`; do not add it here.
# Output is teed to a temp log via process substitution so that the PID we
# signal (_MULTIRUN_PID) remains multirun itself, keeping forwarding intact.
# Failure reporting logic lives in lib/logging.sh, shared with tests
# shellcheck source=lib/logging.sh
. "$(dirname "$0")/lib/logging.sh"
_DAEMON_LOG=$(mktemp)
multirun \
    "sh -c 'exec dnsmasq --no-daemon 2>&1 | sed \"s/^/[dnsmasq] /\"'" \
    "sh -c 'exec /usr/sbin/hostapd /etc/hostapd.conf 2>&1 | sed \"s/^/[hostapd] /\"'" \
    > >(tee "${_DAEMON_LOG}") 2>&1 &
_MULTIRUN_PID=$!

wait "${_MULTIRUN_PID}"
STATUS=$?

cleanup

if [ "${_SIGNALED}" = "1" ] ; then
    rm -f "${_DAEMON_LOG}"
    exit 0
fi
if [ "${STATUS}" -ne 0 ] ; then
    report_failure "${STATUS}" "${_DAEMON_LOG}"
fi
rm -f "${_DAEMON_LOG}"
exit "${STATUS}"
