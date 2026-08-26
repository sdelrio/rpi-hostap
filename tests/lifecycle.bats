#!/usr/bin/env bats

# Tests for the phase-based lifecycle (issue #241)

setup() {
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/lifecycle.sh"
}

teardown() {
    # Reset registration state between tests
    PHASE_PRE_VALIDATE=()
    PHASE_VALIDATE=()
    PHASE_PRE_SETUP=()
    PHASE_POST_SETUP=()
    PHASE_TEARDOWN=()
    _TEARDOWN_DONE=0
}

@test "lifecycle registers hooks into named phase arrays" {
    lifecycle_register teardown nat_remove_rules
    lifecycle_register post_setup radio_apply_tx_power
    [ "${#PHASE_TEARDOWN[@]}" -eq 1 ]
    [ "${PHASE_TEARDOWN[0]}" = "nat_remove_rules" ]
    [ "${#PHASE_POST_SETUP[@]}" -eq 1 ]
    [ "${PHASE_POST_SETUP[0]}" = "radio_apply_tx_power" ]
}

@test "modules register teardown hooks at source time" {
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/nat.sh"
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/ipv6.sh"
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/interface.sh"
    [ "${#PHASE_TEARDOWN[@]}" -eq 3 ]
    # Reverse-dependency order: nat -> ipv6 -> interface
    [ "${PHASE_TEARDOWN[0]}" = "nat_remove_rules" ]
    [ "${PHASE_TEARDOWN[1]}" = "ipv6_teardown" ]
    [ "${PHASE_TEARDOWN[2]}" = "interface_teardown" ]
}

@test "run_phase executes hooks in registration order and returns 0 when all pass" {
    local log
    log=$(mktemp)
    export LOG_PATH="$log"
    first_hook() { echo first >> "${LOG_PATH}"; }
    second_hook() { echo second >> "${LOG_PATH}"; }
    lifecycle_register pre_setup first_hook
    lifecycle_register pre_setup second_hook
    run lifecycle_run_phase pre_setup
    [ "$status" -eq 0 ]
    [ "$(cat "$log")" = $'first\nsecond' ]
    rm -f "$log"
}

@test "run_phase stops at the first failing hook and returns non-zero" {
    local log
    log=$(mktemp)
    ok_hook() { echo ok >> "$log"; }
    bad_hook() { return 7; }
    skipped_hook() { echo skipped >> "$log"; }
    lifecycle_register validate "ok_hook"
    lifecycle_register validate "bad_hook"
    lifecycle_register validate "skipped_hook"
    run lifecycle_run_phase validate
    [ "$status" -ne 0 ]
    [ "$(cat "$log")" = "ok" ]
    ! grep -q skipped "$log"
    rm -f "$log"
}

@test "run_phase is a no-op for an unregistered phase" {
    run lifecycle_run_phase post_setup
    [ "$status" -eq 0 ]
}

@test "cleanup is driven by registered teardown hooks, not hardcoded calls" {
    local log
    log=$(mktemp)
    my_teardown() { echo "my_teardown ran" >> "$log"; }
    lifecycle_register teardown my_teardown
    eval "$(sed -n '/^cleanup()/,/^}/p' "$(dirname "$BATS_TEST_FILENAME")/../wlanstart.sh")"
    run cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"Shutting down..."* ]]
    grep -q "my_teardown ran" "$log"
    grep -q "my_teardown ran" "$log"
    rm -f "$log"
}

@test "wlanstart cleanup contains no feature-specific teardown calls" {
    local body
    body=$(sed -n '/^cleanup()/,/^}/p' "$(dirname "$BATS_TEST_FILENAME")/../wlanstart.sh")
    ! grep -qE 'nat_remove_rules|ipv6_remove_rules|interface_teardown|nat_apply_rules|ip6tables|iptables|ip addr|ip link' <<<"$body"
    grep -q 'lifecycle_run_teardown' <<<"$body"
}

@test "lifecycle_run_teardown runs the teardown phase exactly once" {
    local count=0
    counting_teardown() { count=$((count + 1)); }
    lifecycle_register teardown counting_teardown
    lifecycle_run_teardown
    lifecycle_run_teardown
    lifecycle_run_teardown
    [ "${count}" -eq 1 ]
}

@test "teardown runs exactly once even when a signal arrives mid-setup" {
    local log script
    log=$(mktemp)
    script=$(mktemp)
    cat > "${script}" <<EOF
. "$(dirname "$BATS_TEST_FILENAME")/../lib/lifecycle.sh"
sig_teardown() { echo "teardown" >> "${log}"; }
lifecycle_register teardown sig_teardown
eval "\$(sed -n '/^cleanup()/,/^}/p' "$(dirname "$BATS_TEST_FILENAME")/../wlanstart.sh")"
eval "\$(sed -n '/^check_interrupted()/,/^}/p' "$(dirname "$BATS_TEST_FILENAME")/../wlanstart.sh")"
_SIGNALED=1
# Signal mid-setup: check_interrupted triggers cleanup...
check_interrupted
# ...and the normal end-of-run path calls cleanup again.
cleanup
EOF
    run bash "${script}"
    [ "$status" -eq 0 ]
    [ "$(grep -c teardown "${log}")" -eq 1 ]
    rm -f "${log}" "${script}"
}

@test "a module can add setup+teardown behavior without editing wlanstart.sh" {
    local log
    log=$(mktemp)
    feature_setup() { echo "setup" >> "$log"; }
    feature_teardown() { echo "teardown" >> "$log"; }
    lifecycle_register pre_setup feature_setup
    lifecycle_register teardown feature_teardown
    lifecycle_run_phase pre_setup
    lifecycle_run_teardown
    [ "$(cat "$log")" = $'setup\nteardown' ]
    rm -f "$log"
}

@test "wlanstart runs cleanup when a setup-phase hook fails" {
    local snippet
    for phase in pre_setup post_setup ; do
        snippet=$(grep -F "lifecycle_run_phase ${phase} ||" "$(dirname "$BATS_TEST_FILENAME")/../wlanstart.sh")
        [[ "${snippet}" == *"cleanup"* ]]
        [[ "${snippet}" != *"|| exit 1"* ]]
    done
}

@test "teardown hooks run when a post_setup hook fails" {
    local log script
    log=$(mktemp)
    script=$(mktemp)
    cat > "${script}" <<INNER
. "$(dirname "$BATS_TEST_FILENAME")/../lib/lifecycle.sh"
. "$(dirname "$BATS_TEST_FILENAME")/../lib/nat.sh"
. "$(dirname "$BATS_TEST_FILENAME")/../lib/interface.sh"
. "$(dirname "$BATS_TEST_FILENAME")/../lib/ipv6.sh"
eval "\$(sed -n '/^cleanup()/,/^}/p' "$(dirname "$BATS_TEST_FILENAME")/../wlanstart.sh")"
export INTERFACE=wlan0 SUBNET=192.168.254.0 OUTGOINGS=
iptables() { echo "iptables \$*" >> "${log}"; }
ip() { : ; }
failing_post_setup_hook() { return 9; }
lifecycle_register post_setup failing_post_setup_hook
$(grep -F 'lifecycle_run_phase post_setup ||' "$(dirname "$BATS_TEST_FILENAME")/../wlanstart.sh")
INNER
    run bash "${script}"
    [ "$status" -ne 0 ]
    grep -q "iptables -t nat -D POSTROUTING" "${log}"
    rm -f "${log}" "${script}"
}
