#!/usr/bin/env bats

# Tests exercise atomic_write_config() from lib/sys/atomic.sh - the exact code
# used by wlanstart.sh (no duplicated logic) - together with the real
# hostapd_conf_emit/dnsmasq_conf_emit emitters, covering the failure
# paths from issue #157: failed config generation must leave any
# pre-existing config untouched.

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"
_LOCAL_DIR=""

setup() {
    target=$(mktemp)
    printf 'OLD-CONFIG\n' > "${target}"
    _LOCAL_DIR=""
}

teardown() {
    rm -f "${target}"
    [ -z "${_LOCAL_DIR:-}" ] || rm -rf "${_LOCAL_DIR}"
}

load_emit_fns() {
    export INTERFACE=wlan0
    . "${LIB_DIR}/bootstrap.sh"
    require_module hostapd_conf dnsmasq_conf atomic
}

@test "invalid WPA_VERSION leaves pre-existing hostapd.conf untouched" {
    load_emit_fns
    WPA_VERSION=1   # rejected by wpa_compute_conf
    run atomic_write_config hostapd_conf_emit "${target}"
    [ "$status" -ne 0 ]
    [ "$(cat "${target}")" = "OLD-CONFIG" ]
}

@test "invalid DHCP_RANGE leaves pre-existing dnsmasq.conf untouched" {
    load_emit_fns
    DHCP_RANGE=not-an-ip,192.168.254.200,255.255.255.0,12h
    run atomic_write_config dnsmasq_conf_emit "${target}"
    [ "$status" -ne 0 ]
    [ "$(cat "${target}")" = "OLD-CONFIG" ]
}

@test "failed emit leaves no orphaned temp files in target directory" {
    . "$LIB_DIR/sys/atomic.sh"
    _LOCAL_DIR=$(mktemp -d)
    local_target="${_LOCAL_DIR}/hostapd.conf"
    printf 'OLD-CONFIG\n' > "${local_target}"
    bad_emit() { return 1; }
    run atomic_write_config bad_emit "${local_target}"
    [ "$status" -ne 0 ]
    [ "$(cat "${local_target}")" = "OLD-CONFIG" ]
    [ "$(ls -A "${_LOCAL_DIR}" | sort | tr '\n' ' ')" = "hostapd.conf " ]
}

@test "successful generation replaces the target content atomically" {
    . "$LIB_DIR/sys/atomic.sh"
    # use a representative emitter to verify the atomic replace path.
    good_emit() { printf 'interface=wlan0\n'; }
    run atomic_write_config good_emit "${target}"
    [ "$status" -eq 0 ]
    grep -q 'interface=wlan0' "${target}"
    ! grep -q 'OLD-CONFIG' "${target}"
}

@test "successful generation preserves the target permissions" {
    . "$LIB_DIR/sys/atomic.sh"
    chmod 640 "${target}"
    good_emit() { printf 'interface=wlan0\n'; }
    run atomic_write_config good_emit "${target}"
    [ "$status" -eq 0 ]
    [ "$(stat -c '%a' "${target}" 2>/dev/null || stat -f '%Lp' "${target}")" = "640" ]
}

@test "temp file is created next to the target (same filesystem)" {
    . "$LIB_DIR/sys/atomic.sh"
    _LOCAL_DIR=$(mktemp -d)
    local_target="${_LOCAL_DIR}/hostapd.conf"
    printf 'OLD-CONFIG\n' > "${local_target}"
    good_emit() { printf 'interface=wlan0\n'; }
    run atomic_write_config good_emit "${local_target}"
    [ "$status" -eq 0 ]
    grep -q 'interface=wlan0' "${local_target}"
    # no leftover temp files in the target directory
    [ "$(ls -A "${_LOCAL_DIR}" | sort | tr '\n' ' ')" = "hostapd.conf " ]
}
