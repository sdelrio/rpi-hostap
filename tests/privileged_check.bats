#!/usr/bin/env bats

# Tests for the iptables-based privileged-mode check (issue #228)

SCRIPT="${BATS_TEST_DIRNAME}/../wlanstart.sh"

setup() {
    STUBDIR="${BATS_TEST_TMPDIR}/iptables-stubs"
    mkdir -p "${STUBDIR}"
}

make_iptables_stub() {
    printf '#!/bin/bash\n%b\n' "$1" > "${STUBDIR}/iptables"
    chmod +x "${STUBDIR}/iptables"
}

@test "unprivileged mode (iptables probe fails) aborts before interface check" {
    make_iptables_stub 'exit 3'
    run bash -c "IPTABLES_BASE='${STUBDIR}/iptables' '${SCRIPT}' </dev/null 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Not running in privileged mode (cannot access iptables)."* ]]
    [[ "$output" != *"An interface must be specified."* ]]
}

@test "privileged mode (iptables probe succeeds) passes the check" {
    make_iptables_stub 'exit 0'
    run bash -c "PATH='${STUBDIR}:/usr/bin:/bin' IPTABLES_BASE='${STUBDIR}/iptables' '${SCRIPT}' </dev/null 2>&1"
    [[ "$output" != *"Not running in privileged mode"* ]]
    # Proceeds past the check far enough to hit the next validator
    [[ "$output" == *"An interface must be specified."* ]]
}

@test "--validate bypasses the iptables privileged-mode check" {
    make_iptables_stub 'exit 3'
    run bash -c "IPTABLES_BASE='${STUBDIR}/iptables' '${SCRIPT}' --validate </dev/null 2>&1"
    [[ "$output" != *"Not running in privileged mode"* ]]
}
