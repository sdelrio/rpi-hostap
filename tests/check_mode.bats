#!/usr/bin/env bats

# Tests for wlanstart.sh --check runtime state audit (issue #288)

SCRIPT="${BATS_TEST_DIRNAME}/../wlanstart.sh"

setup() {
    export INTERFACE="wlan0"
    export SUBNET="192.168.254.0"
    export AP_ADDR="192.168.254.1"
    export OUTGOINGS=""
    export IPV6="0"
}

# Source the module with stubbed system tools; $1 = path to a stub dir
# containing ip/iptables/ip6tables, plus a proc dir for sysctls.
load_check() {
    local stubdir="${BATS_TEST_TMPDIR}/stubs"
    local procdir="${BATS_TEST_TMPDIR}/proc"
    mkdir -p "${stubdir}" "${procdir}"
    printf '#!/bin/bash\ncase "$1 $2" in "link show") echo "3: ${INTERFACE}: <BROADCAST,MULTICAST,UP,LOWER_UP> state UP" ;; "addr show") echo "    inet ${AP_ADDR}/${DHCP_PREFIX:-24} scope global ${INTERFACE}" ;; esac\nexit 0\n' > "${stubdir}/ip"
    printf '#!/bin/bash\necho "[stub] iptables $*"\nexit 0\n' > "${stubdir}/iptables"
    printf '#!/bin/bash\necho "[stub] ip6tables $*"\nexit 0\n' > "${stubdir}/ip6tables"
    chmod +x "${stubdir}"/ip "${stubdir}"/iptables "${stubdir}"/ip6tables
    # shellcheck source=../lib/sys/nat.sh
    . "${BATS_TEST_DIRNAME}/../lib/sys/nat.sh"
    # shellcheck source=../../lib/sys/check.sh
    . "${BATS_TEST_DIRNAME}/../lib/sys/check.sh"
    CHECK_IP_BASE="${stubdir}/ip"
    IPTABLES_BASE="${stubdir}/iptables"
    IP6TABLES_BASE="${stubdir}/ip6tables"
    CHECK_SYSCTL_BASE="${procdir}"
}

@test "check_run_audit reports OK and exits 0 when all checks pass" {
    load_check
    echo 1 > "${CHECK_SYSCTL_BASE}/ip_forward"
    echo 1 > "${CHECK_SYSCTL_BASE}/ip_dynaddr"
    run check_run_audit
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK]   MASQUERADE rule for 192.168.254.0/24"* ]]
    [[ "$output" == *"[OK]   FORWARD rules for wlan0"* ]]
    [[ "$output" == *"[OK]   sysctls ip_forward/ip_dynaddr = 1"* ]]
    [[ "$output" != *"[FAIL]"* ]]
}

@test "check_run_audit lists every failure and exits non-zero" {
    load_check
    IPTABLES_BASE="${BATS_TEST_TMPDIR}/no-such-iptables"
    rm -f "${CHECK_SYSCTL_BASE}/ip_forward" "${CHECK_SYSCTL_BASE}/ip_dynaddr"
    run check_run_audit
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL] MASQUERADE rule for 192.168.254.0/24"* ]]
    [[ "$output" == *"[FAIL] FORWARD rules for wlan0"* ]]
    [[ "$output" == *"[FAIL] sysctls ip_forward/ip_dynaddr = 1"* ]]
    [[ "$output" == *"Check failed with 3 failure(s)."* ]]
}

@test "check skips ip6tables item when IPV6 not enabled" {
    load_check
    IPV6=0 run check_run_audit
    [ "$status" -eq 1 ] || true
    [[ "$output" != *"ip6tables FORWARD rules"* ]]
}

@test "check audits ip6tables item when IPV6=1" {
    load_check
    echo 1 > "${CHECK_SYSCTL_BASE}/ip_forward"
    echo 1 > "${CHECK_SYSCTL_BASE}/ip_dynaddr"
    IPV6=1 IP6TABLES_BASE="${BATS_TEST_TMPDIR}/no-such-ip6tables" run check_run_audit
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL] ip6tables FORWARD rules for wlan0"* ]]
}

@test "check uses DHCP_PREFIX in reported prefix" {
    load_check
    DHCP_PREFIX=28
    echo 1 > "${CHECK_SYSCTL_BASE}/ip_forward"
    echo 1 > "${CHECK_SYSCTL_BASE}/ip_dynaddr"
    run check_run_audit
    [ "$status" -eq 1 ]
    [[ "$output" == *"MASQUERADE rule for 192.168.254.0/28"* ]]
}

@test "--check never mutates state" {
    local stubdir="${BATS_TMPDIR}/check-mode-stubs"
    mkdir -p "${stubdir}"
    local tool
    for tool in hostapd dnsmasq multirun ; do
        printf '#!/bin/bash\necho "[Error] %s must not be called in check mode" >&2\nexit 99\n' "${tool}" > "${stubdir}/${tool}"
        chmod +x "${stubdir}/${tool}"
    done
    # Mutating iptables/ip verbs fail loudly; only read-only ones pass.
    printf '#!/bin/bash\ncase "$1" in -A|-D|-N|-I|add|del|flush|set) echo "[Error] mutation attempted" >&2; exit 99 ;; esac\nexit 1\n' > "${stubdir}/iptables"
    cp "${stubdir}/iptables" "${stubdir}/ip6tables"
    printf '#!/bin/bash\ncase "$1 $2" in "link set"|"addr add"|"addr del"|"addr flush") echo "[Error] mutation attempted" >&2; exit 99 ;; esac\nexit 1\n' > "${stubdir}/ip"
    chmod +x "${stubdir}"/iptables "${stubdir}"/ip6tables "${stubdir}"/ip

    run env -i PATH="${stubdir}:/usr/bin:/bin" HOME="${HOME}" \
        INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret \
        "${SCRIPT}" --check
    [ "$status" -eq 1 ]
    [[ "$output" != *"mutation attempted"* ]]
    [[ "$output" != *"must not be called"* ]]
}

@test "--check exits non-zero listing failures against live-ish stubs" {
    run env -i PATH="${PATH}" HOME="${HOME}" \
        INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret \
        "${SCRIPT}" --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL]"* ]]
    [[ "$output" == *"Check failed with"* ]]
}

@test "-c alias behaves like --check" {
    run env -i PATH="${PATH}" HOME="${HOME}" \
        INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret "${SCRIPT}" -c
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL]"* ]]
}
