#!/usr/bin/env bats

# Tests targeting the shared env helpers in lib/client_env.sh (issue #243).

load_client_env() {
    run bash -c 'set -euo pipefail; source lib/client_env.sh; '"$1"
}

setup() {
    unset INTERFACE
    unset CTRL_IFACE_DIR
    cd "${BATS_TEST_DIRNAME}/.."
}

@test "client_env_require_interface exits 1 with canonical error when INTERFACE unset" {
    load_client_env 'client_env_require_interface'
    [ "$status" -eq 1 ]
    [ "${lines[0]}" = "[Error] INTERFACE must be set." ]
}

@test "client_env_require_interface passes when INTERFACE is set" {
    load_client_env 'INTERFACE=wlan0; client_env_require_interface; echo ok'
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "client_env_resolve_ctrl_iface_dir defaults to /var/run/hostapd" {
    load_client_env 'client_env_resolve_ctrl_iface_dir; echo "$CTRL_IFACE_DIR"'
    [ "$status" -eq 0 ]
    [ "$output" = "/var/run/hostapd" ]
}

@test "client_env_resolve_ctrl_iface_dir preserves explicit value" {
    load_client_env 'CTRL_IFACE_DIR=/custom/dir; client_env_resolve_ctrl_iface_dir; echo "$CTRL_IFACE_DIR"'
    [ "$status" -eq 0 ]
    [ "$output" = "/custom/dir" ]
}

@test "client_env_require_ctrl_interface errors with actionable hint when dir missing" {
    load_client_env 'INTERFACE=wlan0; CTRL_IFACE_DIR=/nonexistent/hostapd; client_env_require_ctrl_interface'
    [ "$status" -ne 0 ]
    [ "${lines[0]}" = "[Error] Control interface not available at /nonexistent/hostapd." ]
    [ "${lines[1]}" = "Restart the container with -e CTRL_INTERFACE=1 to enable it." ]
}

@test "client_env_require_ctrl_interface succeeds when dir exists and applies default path" {
    local tmpdir="${BATS_TEST_TMPDIR}/hostapd"
    mkdir -p "$tmpdir"
    load_client_env "INTERFACE=wlan0; CTRL_IFACE_DIR=${tmpdir}; client_env_require_ctrl_interface && client_env_resolve_ctrl_iface_dir; echo \"\$CTRL_IFACE_DIR\""
    [ "$status" -eq 0 ]
}
