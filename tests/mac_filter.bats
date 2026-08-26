#!/usr/bin/env bats

# Logic shared with wlanstart.sh
REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
# shellcheck source=../lib/mac_filter.sh
. "${REPO_ROOT}/lib/mac_filter.sh"

setup() {
    unset MAC_FILTER MAC_ACL_FILE
}

@test "MAC filter disabled by default: silent no-op success" {
    run mac_filter_compute_conf
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "MAC_FILTER=0 explicitly: silent no-op success" {
    MAC_FILTER=0
    run mac_filter_compute_conf
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "MAC_FILTER=1 emits macaddr_acl=1 and accept_mac_file" {
    MAC_FILTER=1
    MAC_ACL_FILE="/etc/hostapd.accept"
    run mac_filter_compute_conf
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "macaddr_acl=1" ]
    [ "${lines[1]}" = "accept_mac_file=/etc/hostapd.accept" ]
}

@test "MAC_FILTER=2 emits macaddr_acl=1 and deny_mac_file" {
    MAC_FILTER=2
    MAC_ACL_FILE="/etc/hostapd.deny"
    run mac_filter_compute_conf
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "macaddr_acl=1" ]
    [ "${lines[1]}" = "deny_mac_file=/etc/hostapd.deny" ]
}

@test "validation passes when filter disabled without file" {
    run mac_filter_validate
    [ "$status" -eq 0 ]
}

@test "validation errors if allowlist enabled without file" {
    MAC_FILTER=1
    unset MAC_ACL_FILE
    run mac_filter_validate
    [ "$status" -eq 1 ]
    [[ "${output}" == *"[Error]"*"MAC_ACL_FILE"* ]]
}

@test "validation errors if denylist enabled without file" {
    MAC_FILTER=2
    unset MAC_ACL_FILE
    run mac_filter_validate
    [ "$status" -eq 1 ]
}

@test "validation warns if ACL file missing" {
    MAC_FILTER=1
    MAC_ACL_FILE="${BATS_TEST_TMPDIR}/does-not-exist"
    run mac_filter_validate
    [ "$status" -eq 0 ]
    [[ "${output}" == *"[Warning]"* ]]
}

@test "validation passes silently if ACL file readable" {
    local f="${BATS_TEST_TMPDIR}/acl"
    echo "aa:bb:cc:dd:ee:ff" > "${f}"
    MAC_FILTER=2
    MAC_ACL_FILE="${f}"
    run mac_filter_validate
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "validation rejects invalid MAC_FILTER value" {
    MAC_FILTER=3
    MAC_ACL_FILE="/etc/hostapd.accept"
    run mac_filter_validate
    [ "$status" -eq 1 ]
    [[ "${output}" == *"[Error]"*"Invalid MAC_FILTER"* ]]
}
