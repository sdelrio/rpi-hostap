#!/usr/bin/env bats

# Tests for handling signals received before multirun starts (issue #115)

SCRIPT="${BATS_TEST_DIRNAME}/../wlanstart.sh"

extract_functions() {
    echo ". '${BATS_TEST_DIRNAME}/../lib/nat.sh'"
    echo ". '${BATS_TEST_DIRNAME}/../lib/interface.sh'"
    echo ". '${BATS_TEST_DIRNAME}/../lib/ipv6.sh'"
    sed -n '/^cleanup()/,/^}/p; /^_MULTIRUN_PID=""$/p; /^_SIGNALED=0$/p; /^handle_signal()/,/^}/p; /^check_interrupted()/,/^}/p' "${SCRIPT}"
}

@test "check_interrupted is defined" {
    eval "$(extract_functions)"
    [ "$(type -t check_interrupted)" = "function" ]
}

@test "check_interrupted exits 0 and runs cleanup when _SIGNALED=1" {
    local mock_log
    mock_log=$(mktemp)
    run bash -c "
$(extract_functions)
iptables() { echo \"iptables \$@\" >> '${mock_log}'; }
ip() { echo \"ip \$@\" >> '${mock_log}'; }
export INTERFACE=wlan0 SUBNET=192.168.254.0 OUTGOINGS=
_SIGNALED=1
check_interrupted
echo REACHED_AFTER_CHECK
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Shutting down..."* ]]
    [[ "$output" == *"[Info] Shutdown requested during startup."* ]]
    grep -q 'iptables -t nat -D POSTROUTING' "${mock_log}"
    [[ "$output" != *"REACHED_AFTER_CHECK"* ]]
    rm -f "${mock_log}"
}

@test "check_interrupted writes shutdown notice to stderr" {
    run bash -c "
$(extract_functions)
cleanup() { : ; }
_SIGNALED=1
check_interrupted
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Info] Shutdown requested during startup."* ]]
}

@test "check_interrupted does nothing when _SIGNALED=0" {
    run bash -c "
$(extract_functions)
cleanup() { echo 'CLEANUP RAN'; }
multirun() { echo 'MULTIRUN STARTED'; }
_SIGNALED=0
check_interrupted
multirun
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MULTIRUN STARTED"* ]]
    [[ "$output" != *"CLEANUP RAN"* ]]
    [[ "$output" != *"Shutdown requested"* ]]
}

@test "trap fires on SIGTERM before multirun and startup aborts with exit 0" {
    local mock_log
    mock_log=$(mktemp)
    run bash -c "
$(extract_functions)
cleanup() { echo 'CLEANUP RAN'; }
multirun() { echo 'MULTIRUN STARTED' >> '${mock_log}'; }
trap handle_signal SIGINT SIGTERM SIGHUP
kill -TERM \$\$
check_interrupted
echo 'Starting dnsmasq and hostapd via multirun ...'
multirun
"
    rm -f "${mock_log}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLEANUP RAN"* ]]
    [[ "$output" == *"[Info] Shutdown requested during startup."* ]]
    [[ "$output" != *"Starting dnsmasq and hostapd via multirun"* ]]
}

@test "without signal, startup proceeds past check_interrupted to multirun" {
    local mock_log
    mock_log=$(mktemp)
    export MOCK_LOG="${mock_log}"
    run bash -c "
$(extract_functions)
cleanup() { echo 'CLEANUP RAN'; }
trap handle_signal SIGINT SIGTERM SIGHUP
check_interrupted
echo 'Starting dnsmasq and hostapd via multirun ...'
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Starting dnsmasq and hostapd via multirun ..."* ]]
    [[ "$output" != *"CLEANUP RAN"* ]]
    [[ "$output" != *"Shutdown requested"* ]]
}

@test "teardown waits for multirun children to exit after signal (issue #183)" {
    local events
    events=$(mktemp)
    run bash -c "
$(extract_functions)
EVENTS='${events}'
iptables() { : ; }
ip() { : ; }
cleanup() {
    if kill -0 \"\${_MULTIRUN_PID}\" 2>/dev/null ; then
        echo 'CLEANUP_DURING_CHILD' >> \"\${EVENTS}\"
    else
        echo 'CLEANUP_AFTER_CHILD' >> \"\${EVENTS}\"
    fi
}
trap handle_signal SIGINT SIGTERM SIGHUP
multirun() {
    # Simulate a child that takes a moment to die after multirun relays
    sleep 0.3 &
    CHILD_PID=\$!
    _MULTIRUN_PID=\$!
}
export -f cleanup
multirun
kill -TERM \$_MULTIRUN_PID
wait \${_MULTIRUN_PID} 2>/dev/null
while kill -0 \${_MULTIRUN_PID} 2>/dev/null ; do
    wait \${_MULTIRUN_PID} 2>/dev/null || true
    sleep 0.1
done
cleanup
"
    [ "$status" -eq 0 ]
    grep -q 'CLEANUP_AFTER_CHILD' "${events}"
    ! grep -q 'CLEANUP_DURING_CHILD' "${events}"
    rm -f "${events}"
}

@test "check_interrupted is called at each key point before multirun" {
    local ci_calls multi_line
    ci_calls=$(grep -n '^\s*check_interrupted\s*$' "${SCRIPT}" | tail -1 | cut -d: -f1)
    multi_line=$(grep -n '^multirun ' "${SCRIPT}" | head -1 | cut -d: -f1)
    [ -n "${ci_calls}" ]
    [ -n "${multi_line}" ]
    [ "${ci_calls}" -lt "${multi_line}" ]
    # at least: after preflight checks, after hostapd.conf, after ip setup, after iptables
    [ "$(grep -c '^\s*check_interrupted\s*$' "${SCRIPT}")" -ge 4 ]
}
