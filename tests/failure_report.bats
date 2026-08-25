#!/usr/bin/env bats

# Tests for tagged daemon output and failing-daemon report (issue #119)

SCRIPT="${BATS_TEST_DIRNAME}/../wlanstart.sh"

load_logging() {
    # shellcheck source=../lib/logging.sh
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/logging.sh"
}

@test "report_failure is defined after loading lib/logging.sh" {
    load_logging
    [ "$(type -t report_failure)" = "function" ]
}

@test "report_failure points at last tagged daemon line" {
    load_logging
    local log
    log=$(mktemp)
    printf '[dnsmasq] started\n[hostapd] line 1\n[hostapd] IEEE 802.11 driver not found\n' > "${log}"
    run report_failure 1 "${log}"
    rm -f "${log}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Error] Container exiting (status 1): check [hostapd] lines above for startup failure."* ]]
}

@test "report_failure falls back to generic tag when log empty" {
    load_logging
    run report_failure 3 ""
    [[ "$output" == *"[daemon] lines above for startup failure."* ]]
}

@test "report_failure falls back to generic tag when no tags present" {
    load_logging
    local log
    log=$(mktemp)
    printf 'some untagged output\n' > "${log}"
    run report_failure 2 "${log}"
    rm -f "${log}"
    [[ "$output" == *"check [daemon] lines"* ]]
}

@test "report_failure writes to stderr" {
    load_logging
    run bash -c ". '${BATS_TEST_DIRNAME}/../lib/logging.sh'; report_failure 1"
    [[ "$output" == *"[Error]"* ]]
}

@test "report_failure preserves full log at FAILURE_LOG_PATH and mentions it" {
    load_logging
    local log dest
    log=$(mktemp)
    dest=$(mktemp)
    printf '[dnsmasq] started\n[hostapd] IEEE 802.11 driver not found\n' > "${log}"
    FAILURE_LOG_PATH="${dest}" run report_failure 1 "${log}"
    rm -f "${log}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Full daemon log saved to ${dest}."* ]]
    diff "${dest}" <(printf '[dnsmasq] started\n[hostapd] IEEE 802.11 driver not found\n')
    rm -f "${dest}"
}

@test "report_failure does not mention saved log when none given" {
    load_logging
    run report_failure 2 ""
    [[ "$output" != *"saved to"* ]]
}

@test "report_failure warns and continues when FAILURE_LOG_PATH is unwritable" {
    load_logging
    local log
    log=$(mktemp)
    printf '[hostapd] driver missing\n' > "${log}"
    FAILURE_LOG_PATH="/nonexistent-dir-162/failure.log" run report_failure 1 "${log}"
    rm -f "${log}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: could not save daemon log to /nonexistent-dir-162/failure.log."* ]]
    [[ "$output" != *"Full daemon log saved"* ]]
}

@test "wlanstart reports failing daemon on non-signal exit" {
    grep -q 'report_failure "${STATUS}"' "${SCRIPT}"
}

@test "wlanstart removes temp daemon log only on clean shutdown (#162)" {
    run grep -A4 'if \[ "\${STATUS}" -ne 0 \] ; then' "${SCRIPT}"
    [[ "$output" == *"report_failure"* ]]
    # failure branch must NOT delete the temp log; the rm lives in else/clean path
    run bash -c "grep -c 'rm -f \"\${_DAEMON_LOG}\"' '${SCRIPT}'"
    [ "$output" -ge 1 ]
}

@test "end-to-end: non-zero exit retains log at FAILURE_LOG_PATH" {
    local dest
    dest=$(mktemp)
    run env FAILURE_LOG_PATH="${dest}" bash -c "
$(sed -n '/^_MULTIRUN_PID=\"\"$/p; /^_SIGNALED=0$/p' "${SCRIPT}")
cleanup() { : ; }
. '${BATS_TEST_DIRNAME}/../lib/logging.sh'
_DAEMON_LOG=\$(mktemp)
multirun() {
    echo '[hostapd] Could not configure driver mode'
    return 1
}
multirun 'x' 'y' > >(tee \"\${_DAEMON_LOG}\") 2>&1 &
_MULTIRUN_PID=\$!
wait \"\${_MULTIRUN_PID}\"
STATUS=\$?
if [ \"\${STATUS}\" -ne 0 ] ; then
    report_failure \"\${STATUS}\" \"\${_DAEMON_LOG}\"
else
    rm -f \"\${_DAEMON_LOG}\"
fi
exit \"\${STATUS}\"
"
    [ "$status" -eq 1 ]
    [[ "$output" == *"[Error] Container exiting (status 1)"* ]]
    [[ "$output" == *"Full daemon log saved to ${dest}."* ]]
    grep -q '\[hostapd\] Could not configure driver mode' "${dest}"
    rm -f "${dest}" "${_DAEMON_LOG:-/dev/null}" 2>/dev/null || true
}

@test "wlanstart tees multirun output to a log for failure attribution" {
    grep -q 'tee "\${_DAEMON_LOG}"' "${SCRIPT}"
}

@test "signal forwarding unchanged: handle_signal still kills _MULTIRUN_PID" {
    grep -q 'kill "${_MULTIRUN_PID}"' "${SCRIPT}"
}

@test "end-to-end: failing hostapd yields tagged output and final error" {
    run bash -c "
$(sed -n '/^_MULTIRUN_PID=\"\"$/p; /^_SIGNALED=0$/p' "${SCRIPT}")
cleanup() { : ; }
report_failure() { echo \"MOCK_REPORT \$@\"; }
_DAEMON_LOG=\$(mktemp)
# stub multirun: emit tagged lines like real daemons, then die like hostapd
multirun() {
    echo '[dnsmasq] dnsmasq started'
    echo '[hostapd] Could not configure driver mode'
    return 1
}
multirun \\
    'tagged-dnsmasq-cmd' \\
    'tagged-hostapd-cmd' \\
    > >(tee \"\${_DAEMON_LOG}\") 2>&1 &
_MULTIRUN_PID=\$!
wait \"\${_MULTIRUN_PID}\"
STATUS=\$?
if [ \"\${STATUS}\" -ne 0 ] ; then
    report_failure \"\${STATUS}\" \"\${_DAEMON_LOG}\"
fi
rm -f \"\${_DAEMON_LOG}\"
exit \"\${STATUS}\"
"
    [ "$status" -eq 1 ]
    [[ "$output" == *"[dnsmasq] dnsmasq started"* ]]
    [[ "$output" == *"[hostapd] Could not configure driver mode"* ]]
    [[ "$output" == *"MOCK_REPORT 1"* ]]
}
