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

# Dry-run validation mode (--validate, -t/--test): apply env defaults,
# run every validator and print the generated hostapd.conf/dnsmasq.conf
# to stdout instead of touching the system.
VALIDATE_ONLY=0
case "${1:-}" in
    --validate|-t|--test)
        VALIDATE_ONLY=1
        shift
        ;;
    --version|-V)
        if [ -n "${WLANSTART_VERSION:-}" ] ; then
            echo "${WLANSTART_VERSION}"
        elif command -v jq >/dev/null 2>&1 && [ -f "$(dirname "$0")/scripts/get-version.sh" ] ; then
            bash "$(dirname "$0")/scripts/get-version.sh" 2>/dev/null || echo "unknown"
        else
            echo "unknown"
        fi
        exit 0
        ;;
    "")
        ;;
    *)
        echo "[Error] Unknown option '${1}'. Usage: wlanstart.sh [--version|-V|--validate|-t|--test]" >&2
        exit 1
        ;;
esac

if [ "${VALIDATE_ONLY}" != "1" ] ; then
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
fi

# Apply all environment defaults in one place (issue #237).
# Logic lives in lib/env.sh, shared with tests
# shellcheck source=lib/env.sh
. "$(dirname "$0")/lib/env.sh"
resolve_config_env

# Secret-file inputs for SSID/WPA_PASSPHRASE (_FILE convention, issue #232)
# Logic lives in lib/secret_file.sh, shared with tests
# shellcheck source=lib/secret_file.sh
. "$(dirname "$0")/lib/secret_file.sh"
load_from_file SSID SSID_FILE || exit 1
load_from_file WPA_PASSPHRASE WPA_PASSPHRASE_FILE || exit 1

# Validate channel against regulatory domain and hardware mode
# Logic lives in lib/channel.sh, shared with tests
# shellcheck source=lib/channel.sh
. "$(dirname "$0")/lib/channel.sh"

# IPv4 address validation (validate_ipv4)
# Logic lives in lib/validation.sh, shared with tests
# shellcheck source=lib/validation.sh
. "$(dirname "$0")/lib/validation.sh"
# Startup warnings for default credentials
# Logic lives in lib/warnings.sh, shared with tests
# shellcheck source=lib/warnings.sh
. "$(dirname "$0")/lib/warnings.sh"
# WPA_PASSPHRASE length validation
# Logic lives in lib/passphrase.sh, shared with tests
# shellcheck source=lib/passphrase.sh
. "$(dirname "$0")/lib/passphrase.sh"
# MAX_STATIONS
# Logic lives in lib/stations.sh, shared with tests
# shellcheck source=lib/stations.sh
. "$(dirname "$0")/lib/stations.sh"
# WPA version
# Logic lives in lib/wpa.sh, shared with tests
# shellcheck source=lib/wpa.sh
. "$(dirname "$0")/lib/wpa.sh"
# AP isolation
# Logic lives in lib/ap_isolation.sh, shared with tests
# shellcheck source=lib/ap_isolation.sh
. "$(dirname "$0")/lib/ap_isolation.sh"
# Hidden SSID
# Logic lives in lib/ssid_hidden.sh, shared with tests
# shellcheck source=lib/ssid_hidden.sh
. "$(dirname "$0")/lib/ssid_hidden.sh"
# MAC address filtering
# Logic lives in lib/mac_filter.sh, shared with tests
# shellcheck source=lib/mac_filter.sh
. "$(dirname "$0")/lib/mac_filter.sh"
# Control interface
# Logic lives in lib/ctrl_interface.sh, shared with tests
# shellcheck source=lib/ctrl_interface.sh
. "$(dirname "$0")/lib/ctrl_interface.sh"
# Optional IPv6 support
# Logic lives in lib/ipv6.sh, shared with tests
# shellcheck source=lib/ipv6.sh
. "$(dirname "$0")/lib/ipv6.sh"
# DHCP_RANGE computation
# Logic lives in lib/dhcp.sh, shared with tests
# shellcheck source=lib/dhcp.sh
. "$(dirname "$0")/lib/dhcp.sh"
# Extra hostapd.conf options (HOSTAPD_EXTRA_OPTS)
# Logic lives in lib/extra_opts.sh, shared with tests
# shellcheck source=lib/extra_opts.sh
. "$(dirname "$0")/lib/extra_opts.sh"
# TX_POWER transmit power control
# Logic lives in lib/radio.sh, shared with tests
# shellcheck source=lib/radio.sh
. "$(dirname "$0")/lib/radio.sh"
# Atomic config file writing (temp file + mv)
# Logic lives in lib/atomic.sh, shared with tests
# shellcheck source=lib/atomic.sh
. "$(dirname "$0")/lib/atomic.sh"

# Emit hostapd.conf to stdout from the current environment.
emit_hostapd_conf() {
    local wpa_conf ap_isolation_conf ssid_hidden_conf mac_filter_conf max_sta_conf ctrl_conf
    wpa_conf=$(compute_wpa_conf) || return 1
    ap_isolation_conf=$(compute_ap_isolation_line)
    ssid_hidden_conf=$(compute_ssid_hidden_line)
    mac_filter_conf=$(compute_mac_filter_conf)
    max_sta_conf=$(compute_max_sta_conf) || return 1
    ctrl_conf=$(compute_ctrl_interface_conf)

    cat <<EOF
interface=${INTERFACE}
${DRIVER+"driver=${DRIVER}"}
ssid=${SSID}
${ssid_hidden_conf}
hw_mode=${HW_MODE}
channel=${CHANNEL}
${COUNTRY_CODE+"country_code=${COUNTRY_CODE}"}
${wpa_conf}
wpa_ptk_rekey=600
wmm_enabled=1
${max_sta_conf}
${ap_isolation_conf}
${mac_filter_conf}
${ctrl_conf}

# Activate channel selection for HT High Throughput (802.11an)

${HT_ENABLED+"ieee80211n=1"}
${HT_CAPAB+"ht_capab=${HT_CAPAB}"}

# Activate channel selection for VHT Very High Throughput (802.11ac)

${VHT_ENABLED+"ieee80211ac=1"}
${VHT_CAPAB+"vht_capab=${VHT_CAPAB}"}
EOF

    compute_extra_opts_lines
}

# Emit dnsmasq.conf to stdout from the current environment.
emit_dnsmasq_conf() {
    local dhcp_range ipv6_conf=""
    dhcp_range=$(compute_dhcp_range) || return 1
    if [ "${IPV6:-0}" = "1" ] ; then
        ipv6_conf=$(compute_dnsmasq_ipv6_conf)
    fi

    cat <<EOF
interface=${INTERFACE}
dhcp-range=${dhcp_range}
dhcp-option=option:router,${AP_ADDR}
dhcp-option=option:dns-server,${PRI_DNS},${SEC_DNS}
${ipv6_conf}
EOF
}

# Dry-run validation mode: run every validator, collecting all failures
# instead of stopping at the first one. On success print the generated
# config files to stdout; on failure exit non-zero listing the errors
# (validators already report them on stderr).
run_validation_mode() {
    local errors=0

    if [ ! "${INTERFACE:-}" ] ; then
        echo "[Error] An interface must be specified." >&2
        errors=$((errors + 1))
    fi

    validate_channel_strict || errors=$((errors + 1))
    validate_vht || errors=$((errors + 1))

    validate_ipv4_param SUBNET "${SUBNET}" || errors=$((errors + 1))
    validate_ipv4_param AP_ADDR "${AP_ADDR}" || errors=$((errors + 1))
    validate_ipv4_param PRI_DNS "${PRI_DNS}" || errors=$((errors + 1))
    validate_ipv4_param SEC_DNS "${SEC_DNS}" || errors=$((errors + 1))

    emit_credential_warnings >&2 || true
    validate_passphrase || errors=$((errors + 1))
    validate_ssid "${SSID}" || errors=$((errors + 1))
    validate_mac_filter || errors=$((errors + 1))
    validate_tx_power || errors=$((errors + 1))

    if [ "${errors}" -ne 0 ] ; then
        echo "[Error] Validation failed with ${errors} error(s)." >&2
        return 1
    fi

    # Config generation doubles as DHCP range / WPA config validation.
    local hostapd dnsmasq
    hostapd=$(emit_hostapd_conf) || {
        echo "[Error] Invalid WPA configuration." >&2
        return 1
    }
    dnsmasq=$(emit_dnsmasq_conf) || {
        echo "[Error] Invalid DHCP_RANGE." >&2
        return 1
    }

    echo "=== /etc/hostapd.conf ==="
    printf '%s\n' "${hostapd}"
    echo "=== /etc/dnsmasq.conf ==="
    printf '%s\n' "${dnsmasq}"
}

if [ "${VALIDATE_ONLY}" = "1" ] ; then
    run_validation_mode
    exit $?
fi

# Startup warnings for default credentials (normal mode only; validation
# mode emits them above so they are not interleaved with stdout configs).
emit_credential_warnings
if ! validate_passphrase ; then
    exit 1
fi
if ! validate_ssid "${SSID}" ; then
    exit 1
fi
check_interrupted

if ! validate_mac_filter ; then
    exit 1
fi
check_interrupted

if ! validate_channel ; then
    exit 1
fi
check_interrupted

if ! validate_vht ; then
    exit 1
fi
if ! validate_tx_power ; then
    exit 1
fi

validate_ipv4_param SUBNET "${SUBNET}" || exit 1
validate_ipv4_param AP_ADDR "${AP_ADDR}" || exit 1
validate_ipv4_param PRI_DNS "${PRI_DNS}" || exit 1
validate_ipv4_param SEC_DNS "${SEC_DNS}" || exit 1

# Compute DHCP range early so the netmask-derived prefix (DHCP_PREFIX)
# is available for setup_interface and apply_nat_rules.
compute_dhcp_range > /dev/null || exit 1

# Always regenerate hostapd.conf so env var changes apply between runs.
# Generated atomically so a failure leaves the old config intact (#157).
write_atomic_config emit_hostapd_conf "/etc/hostapd.conf" || exit 1
check_interrupted

# Setup interface and restart DHCP service
if ! setup_interface ; then
    exit 1
fi
check_interrupted

# Optional transmit power cap (TX_POWER); fatal on failure (#236)
apply_tx_power || exit 1
check_interrupted

# NAT settings
set_sysctls ip_dynaddr ip_forward
show_sysctls ip_dynaddr ip_forward

apply_nat_rules

# Optional IPv6 support (off by default, enable with IPV6=1)
if [ "${IPV6:-0}" = "1" ] ; then
    echo "Enabling IPv6 forwarding..."
    enable_ipv6_forwarding
    echo "Setting ip6tables rules for outgoing traffics..."
    apply_ipv6_rules
fi

echo "Configuring DHCP server .."

# Always regenerate dnsmasq.conf so env var changes apply between runs.
# Generated atomically so a failure leaves the old config intact (#157).
write_atomic_config emit_dnsmasq_conf "/etc/dnsmasq.conf" || exit 1

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

# When a signal arrives, bash's wait returns immediately (status > 128)
# before multirun has finished relaying the signal to its children.
# Defer teardown until multirun has actually exited (#183).
while kill -0 "${_MULTIRUN_PID}" 2>/dev/null ; do
    wait "${_MULTIRUN_PID}" 2>/dev/null || true
    sleep 0.1
done

cleanup

if [ "${_SIGNALED}" = "1" ] ; then
    # Clean shutdown after signal: temp log is not needed.
    rm -f "${_DAEMON_LOG}"
    exit 0
fi
if [ "${STATUS}" -ne 0 ] ; then
    # Preserve the full tagged daemon log for post-mortem (issue #162);
    # report_failure preserves a timestamped copy and mentions the path.
    # The temp log is only removed on clean shutdown / signal exit.
    report_failure "${STATUS}" "${_DAEMON_LOG}"
else
    rm -f "${_DAEMON_LOG}"
fi
exit "${STATUS}"
