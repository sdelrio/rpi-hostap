#!/bin/bash

# Phase-based lifecycle (issue #241): modules register setup/teardown
# hooks into PHASE_* arrays at source time; cleanup() below just runs
# the teardown phase. Must be sourced before any module that registers
# hooks.
# Declarative module loading (issue #239): bootstrap resolves core/ vs sys/
# paths, tracks what is already loaded (_LOADED) so double-sourcing is a
# no-op, and pulls declared dependencies via require_module.
# shellcheck source=lib/bootstrap.sh
. "$(dirname "$0")/lib/bootstrap.sh"

require_module lifecycle nat interface

# cleanup() is feature-agnostic: every module registers its own teardown
# hook into PHASE_TEARDOWN when its lib is sourced, in reverse-dependency
# order (nat -> ipv6 -> interface). lifecycle_run_teardown guarantees the
# phase runs exactly once even if a signal arrives mid-setup.
cleanup() {
    echo "Shutting down..."

    lifecycle_run_teardown
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
CHECK_ONLY=0
case "${1:-}" in
    --validate|-t|--test)
        VALIDATE_ONLY=1
        shift
        ;;
    --check|-c)
        CHECK_ONLY=1
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
        echo "[Error] Unknown option '${1}'. Usage: wlanstart.sh [--version|-V|--validate|-t|--test|--check|-c]" >&2
        exit 1
        ;;
esac

if [ "${VALIDATE_ONLY}" != "1" ] && [ "${CHECK_ONLY}" != "1" ] ; then
    # Record container start time so healthcheck.sh can measure the grace
    # period from the actual start (not host uptime via /proc/uptime).
    date +%s > /run/hostap-started 2>/dev/null || true

    # Check if running in privileged mode. An iptables listing requires
    # CAP_NET_ADMIN, which unprivileged containers lack and read-only /sys
    # mounts do not affect. IPTABLES_BASE is overridable for tests.
    IPTABLES_BASE="${IPTABLES_BASE:-iptables}"
    if ! "${IPTABLES_BASE}" -t nat -L > /dev/null 2>&1 ; then
        echo "[Error] Not running in privileged mode (cannot access iptables)." >&2
        exit 1
    fi

    # Check environment variables
    if [ ! "${INTERFACE}" ] ; then
        echo "[Error] An interface must be specified."
        exit 1
    fi
fi

# Apply all environment defaults in one place (issue #237).
# Logic lives in lib/core/env.sh, shared with tests
require_module env
env_resolve_config_env

# Secret-file inputs for SSID/WPA_PASSPHRASE (_FILE convention, issue #232)
require_module secret_file
secret_file_load SSID SSID_FILE || exit 1
secret_file_load WPA_PASSPHRASE WPA_PASSPHRASE_FILE || exit 1

# Remaining validation/config modules (each loaded once, idempotently)
require_module channel validation warnings passphrase stations \
    wpa ap_isolation ssid_hidden mac_filter ctrl_interface ipv6 \
    dhcp extra_opts radio atomic

# Config emission lives in lib/core (issue #238); this file only wires the
# generated configs into validation mode and atomic writes below.
require_module hostapd_conf dnsmasq_conf

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

    channel_validate_strict || errors=$((errors + 1))
    channel_validate_vht || errors=$((errors + 1))
    channel_validate_he || errors=$((errors + 1))

    validation_check_ipv4_param SUBNET "${SUBNET}" || errors=$((errors + 1))
    validation_check_ipv4_param AP_ADDR "${AP_ADDR}" || errors=$((errors + 1))
    validation_check_ipv4_param PRI_DNS "${PRI_DNS}" || errors=$((errors + 1))
    validation_check_ipv4_param SEC_DNS "${SEC_DNS}" || errors=$((errors + 1))

    warnings_emit_credential_warnings >&2 || true
    passphrase_validate || errors=$((errors + 1))
    validation_check_ssid "${SSID}" || errors=$((errors + 1))
    mac_filter_validate || errors=$((errors + 1))
    radio_validate_tx_power || errors=$((errors + 1))

    if [ "${errors}" -ne 0 ] ; then
        echo "[Error] Validation failed with ${errors} error(s)." >&2
        return 1
    fi

    # Config generation doubles as DHCP range / WPA config validation.
    local hostapd dnsmasq
    hostapd=$(hostapd_conf_emit) || {
        echo "[Error] Invalid WPA configuration." >&2
        return 1
    }
    dnsmasq=$(dnsmasq_conf_emit) || {
        echo "[Error] Invalid DHCP_RANGE." >&2
        return 1
    }

    echo "=== /etc/hostapd.conf ==="
    printf '%s\n' "${hostapd}"
    echo "=== /etc/dnsmasq.conf ==="
    printf '%s\n' "${dnsmasq}"
}

# Read-only runtime audit (--check, -c): resolve env the same way a normal
# start does, then compare live system state against it per item. Never
# mutates state; exits non-zero listing failures like validation mode.
run_check_mode() {
    local errors=0

    if [ ! "${INTERFACE:-}" ] ; then
        echo "[Error] An interface must be specified." >&2
        return 1
    fi

    if ! DHCP_RANGE_COMPUTED=$(dhcp_compute_range) ; then
        echo "[Error] Invalid DHCP_RANGE." >&2
        return 1
    fi
    export DHCP_RANGE_COMPUTED

    check_run_audit
}

if [ "${CHECK_ONLY}" = "1" ] ; then
    require_module check
    run_check_mode
    exit $?
fi

if [ "${VALIDATE_ONLY}" = "1" ] ; then
    run_validation_mode
    exit $?
fi

# Startup warnings for default credentials (normal mode only; validation
# mode emits them above so they are not interleaved with stdout configs).
warnings_emit_credential_warnings
if ! passphrase_validate ; then
    exit 1
fi
if ! validation_check_ssid "${SSID}" ; then
    exit 1
fi
check_interrupted

if ! mac_filter_validate ; then
    exit 1
fi
check_interrupted

if ! channel_validate ; then
    exit 1
fi
check_interrupted

if ! channel_validate_vht ; then
    exit 1
fi
if ! channel_validate_he ; then
    exit 1
fi
if ! radio_validate_tx_power ; then
    exit 1
fi

validation_check_ipv4_param SUBNET "${SUBNET}" || exit 1
validation_check_ipv4_param AP_ADDR "${AP_ADDR}" || exit 1
validation_check_ipv4_param PRI_DNS "${PRI_DNS}" || exit 1
validation_check_ipv4_param SEC_DNS "${SEC_DNS}" || exit 1

# Compute DHCP range early so the netmask-derived prefix (DHCP_PREFIX)
# is available for interface_setup and nat_apply_rules, and so the
# computed range (and its warnings) is produced exactly once per startup;
# dnsmasq_conf_emit reuses it below (#224).
DHCP_RANGE_COMPUTED=$(dhcp_compute_range) || exit 1
export DHCP_RANGE_COMPUTED

# Always regenerate hostapd.conf so env var changes apply between runs.
# Generated atomically so a failure leaves the old config intact (#157).
atomic_write_config hostapd_conf_emit "/etc/hostapd.conf" || exit 1
check_interrupted

# Setup interface and restart DHCP service
# Modules can register extra pre-setup hooks without editing this file (#241).
# Failure runs cleanup for symmetry with post_setup (harmless before any
# state is applied; protective once hooks mutate state).
lifecycle_run_phase pre_setup || { cleanup ; exit 1 ; }

if ! interface_setup ; then
    exit 1
fi
check_interrupted

# Optional transmit power cap (TX_POWER); fatal on failure (#236)
radio_apply_tx_power || exit 1
check_interrupted

# NAT settings
nat_set_sysctls ip_dynaddr ip_forward
nat_show_sysctls ip_dynaddr ip_forward

nat_apply_rules

# Optional IPv6 support (off by default, enable with IPV6=1)
if [ "${IPV6:-0}" = "1" ] ; then
    echo "Enabling IPv6 forwarding..."
    ipv6_enable_forwarding
    echo "Setting ip6tables rules for outgoing traffics..."
    ipv6_apply_rules
fi

# Modules can register extra post-setup hooks without editing this file (#241).
# On failure run cleanup so already-applied state (interface, NAT, ip6tables)
# is torn down instead of leaking (review of PR #265). The teardown-once
# guard makes this safe even if a signal-triggered cleanup also runs.
lifecycle_run_phase post_setup || { cleanup ; exit 1 ; }

echo "Configuring DHCP server .."

# Always regenerate dnsmasq.conf so env var changes apply between runs.
# Generated atomically so a failure leaves the old config intact (#157).
atomic_write_config dnsmasq_conf_emit "/etc/dnsmasq.conf" || exit 1

echo "Starting dnsmasq and hostapd via multirun ..."
check_interrupted
# Tag each daemon's output so failures are attributable (issue #119).
# NOTE: multirun already wraps each command in `exec`; do not add it here.
# Output is teed to a temp log via process substitution so that the PID we
# signal (_MULTIRUN_PID) remains multirun itself, keeping forwarding intact.
# Failure reporting logic lives in lib/sys/logging.sh, shared with tests
require_module logging
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
    # logging_report_failure preserves a timestamped copy and mentions the path.
    # The temp log is only removed on clean shutdown / signal exit.
    logging_report_failure "${STATUS}" "${_DAEMON_LOG}"
else
    rm -f "${_DAEMON_LOG}"
fi
exit "${STATUS}"
