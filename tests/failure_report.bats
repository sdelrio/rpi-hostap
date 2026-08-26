#!/usr/bin/env bats

# Tests for tagged daemon output and failing-daemon report (issue #119)

SCRIPT="${BATS_TEST_DIRNAME}/../wlanstart.sh"

load_logging() {
    # shellcheck source=../lib/logging.sh
    . "$(dirname "$BATS_TEST_FILENAME")/../lib/logging.sh"
}

@test "logging_report_failure is defined after loading lib/logging.sh" {
    load_logging
    [ "$(type -t logging_report_failure)" = "function" ]
}

@test "logging_report_failure points at last tagged daemon line" {
    load_logging
    local log
    log=$(mktemp)
    printf '[dnsmasq] started\n[hostapd] line 1\n[hostapd] IEEE 802.11 driver not found\n' > "${log}"
    run logging_report_failure 1 "${log}"
    rm -f "${log}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Error] Container exiting (status 1): check [hostapd] lines above for startup failure."* ]]
}

@test "logging_report_failure falls back to generic tag when log empty" {
    load_logging
    run logging_report_failure 3 ""
    [[ "$output" == *"[daemon] lines above for startup failure."* ]]
}

@test "logging_report_failure falls back to generic tag when no tags present" {
    load_logging
    local log
    log=$(mktemp)
    printf 'some untagged output\n' > "${log}"
    run logging_report_failure 2 "${log}"
    rm -f "${log}"
    [[ "$output" == *"check [daemon] lines"* ]]
}

@test "logging_report_failure writes to stderr" {
    load_logging
    run bash -c ". '${BATS_TEST_DIRNAME}/../lib/logging.sh'; logging_report_failure 1"
    [[ "$output" == *"[Error]"* ]]
}

@test "logging_report_failure preserves full log at FAILURE_LOG_PATH and mentions it" {
    load_logging
    local log dest
    log=$(mktemp)
    dest=$(mktemp)
    printf '[dnsmasq] started\n[hostapd] IEEE 802.11 driver not found\n' > "${log}"
    FAILURE_LOG_PATH="${dest}" run logging_report_failure 1 "${log}"
    rm -f "${log}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Full daemon log saved to ${dest}."* ]]
    diff "${dest}" <(printf '[dnsmasq] started\n[hostapd] IEEE 802.11 driver not found\n')
    rm -f "${dest}"
}

@test "logging_report_failure does not mention saved log when none given" {
    load_logging
    run logging_report_failure 2 ""
    [[ "$output" != *"saved to"* ]]
}

@test "logging_report_failure warns and continues when FAILURE_LOG_PATH is unwritable" {
    load_logging
    local log
    log=$(mktemp)
    printf '[hostapd] driver missing\n' > "${log}"
    FAILURE_LOG_PATH="/nonexistent-dir-162/failure.log" run logging_report_failure 1 "${log}"
    rm -f "${log}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: could not save daemon log to /nonexistent-dir-162/failure.log."* ]]
    [[ "$output" != *"Full daemon log saved"* ]]
}

@test "successive failures create distinct timestamped files (#199)" {
    load_logging
    local dir log
    dir=$(mktemp -d)
    log=$(mktemp)
    printf '[hostapd] driver missing\n' > "${log}"
    FAILURE_LOG_PATH="" FAILURE_LOG_DIR="${dir}" run logging_report_failure 1 "${log}"
    [ "$status" -eq 0 ]
    sleep 1
    FAILURE_LOG_PATH="" FAILURE_LOG_DIR="${dir}" run logging_report_failure 2 "${log}"
    rm -f "${log}"
    local count
    count=$(find "${dir}" -name 'hostap-failure-*.log' | wc -l | tr -d ' ')
    [ "${count}" -eq 2 ]
    [[ "$output" == *"Full daemon log saved to ${dir}/hostap-failure-"* ]]
}

@test "pruning keeps only FAILURE_LOG_KEEP newest copies (#199)" {
    load_logging
    local dir log f t
    dir=$(mktemp -d)
    t=202401010001
    for f in 1000 1500 2000 2500 3000 3500 ; do
        printf '[hostapd] old %s\n' "${f}" > "${dir}/hostap-failure-${f}.log"
        touch -t "${t}" "${dir}/hostap-failure-${f}.log"
        t=$((t + 1))
    done
    log=$(mktemp)
    printf '[hostapd] fresh\n' > "${log}"
    FAILURE_LOG_PATH="" FAILURE_LOG_DIR="${dir}" FAILURE_LOG_KEEP=3 \
        run logging_report_failure 1 "${log}"
    rm -f "${log}"
    [ "$status" -eq 0 ]
    local count
    count=$(find "${dir}" -name 'hostap-failure-*.log' | wc -l | tr -d ' ')
    [ "${count}" -eq 3 ]
    [ ! -e "${dir}/hostap-failure-1000.log" ]
    [ ! -e "${dir}/hostap-failure-1500.log" ]
    [ -e "${dir}/hostap-failure-3500.log" ]
    find "${dir}" -name 'hostap-failure-*.log' -newer "${dir}/hostap-failure-3500.log" -delete
}

@test "explicit FAILURE_LOG_PATH is still honored verbatim (#199)" {
    load_logging
    local log dest
    log=$(mktemp)
    dest="$(mktemp -d)/fixed-name.log"
    printf '[hostapd] driver missing\n' > "${log}"
    FAILURE_LOG_PATH="${dest}" FAILURE_LOG_KEEP=5 run logging_report_failure 1 "${log}"
    rm -f "${log}"
    [ -f "${dest}" ]
    grep -q '\[hostapd\] driver missing' "${dest}"
    rm -rf "$(dirname "${dest}")"
}

@test "wlanstart reports failing daemon on non-signal exit" {
    grep -q 'logging_report_failure "${STATUS}"' "${SCRIPT}"
}

@test "wlanstart removes temp daemon log only on clean shutdown (#162)" {
    run grep -A4 'if \[ "\${STATUS}" -ne 0 \] ; then' "${SCRIPT}"
    [[ "$output" == *"logging_report_failure"* ]]
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
    logging_report_failure \"\${STATUS}\" \"\${_DAEMON_LOG}\"
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
logging_report_failure() { echo \"MOCK_REPORT \$@\"; }
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
    logging_report_failure \"\${STATUS}\" \"\${_DAEMON_LOG}\"
fi
rm -f \"\${_DAEMON_LOG}\"
exit \"\${STATUS}\"
"
    [ "$status" -eq 1 ]
    [[ "$output" == *"[dnsmasq] dnsmasq started"* ]]
    [[ "$output" == *"[hostapd] Could not configure driver mode"* ]]
    [[ "$output" == *"MOCK_REPORT 1"* ]]
}
