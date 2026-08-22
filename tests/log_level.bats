#!/usr/bin/env bats

# Helper to extract LOG_LEVEL logic from wlanstart.sh

setup() {
    unset LOG_LEVEL
    unset DNSMASQ_LOG_OPTS
}

validate_log_level() {
    true ${LOG_LEVEL:=2}
    if ! [ "${LOG_LEVEL}" -ge 0 ] 2>/dev/null || ! [ "${LOG_LEVEL}" -le 4 ] 2>/dev/null ; then
        echo "[Warning] Invalid LOG_LEVEL '${LOG_LEVEL}'. Must be an integer between 0 (verbose debug) and 4 (minimal). Using default '2'."
        LOG_LEVEL=2
    fi
    echo "${LOG_LEVEL}"
}

compute_dnsmasq_log_opts() {
    LOG_LEVEL=$(validate_log_level | tail -n 1)
    DNSMASQ_LOG_OPTS=""
    if [ "${LOG_LEVEL}" -le 1 ] 2>/dev/null ; then
        DNSMASQ_LOG_OPTS="--log-queries"
    fi
    echo "${DNSMASQ_LOG_OPTS}"
}

hostapd_log_lines() {
    LOG_LEVEL=$(validate_log_level | tail -n 1)
    cat <<EOF
logger_syslog_level=${LOG_LEVEL}
logger_stdout_level=${LOG_LEVEL}
EOF
}

@test "default LOG_LEVEL is 2" {
    run validate_log_level
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "LOG_LEVEL=0 is accepted" {
    LOG_LEVEL=0
    run validate_log_level
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "LOG_LEVEL=4 is accepted" {
    LOG_LEVEL=4
    run validate_log_level
    [ "$status" -eq 0 ]
    [ "$output" = "4" ]
}

@test "LOG_LEVEL=3 is accepted without warning" {
    LOG_LEVEL=3
    run validate_log_level
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
    [[ "$output" != *"Invalid"* ]]
}

@test "negative LOG_LEVEL falls back to default with warning" {
    LOG_LEVEL=-1
    run validate_log_level
    [ "$status" -eq 0 ]
    [[ "$output" == *"Invalid LOG_LEVEL"* ]]
    [[ "$output" == *"2"* ]]
}

@test "LOG_LEVEL=5 falls back to default with warning" {
    LOG_LEVEL=5
    run validate_log_level
    [ "$status" -eq 0 ]
    [[ "$output" == *"Invalid LOG_LEVEL"* ]]
    [[ "$output" == *"2"* ]]
}

@test "non-numeric LOG_LEVEL falls back to default with warning" {
    LOG_LEVEL="abc"
    run validate_log_level
    [ "$status" -eq 0 ]
    [[ "$output" == *"Invalid LOG_LEVEL"* ]]
    [[ "$output" == *"2"* ]]
}

@test "default produces no dnsmasq log opts" {
    run compute_dnsmasq_log_opts
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "verbose LOG_LEVEL=0 enables dnsmasq query logging" {
    LOG_LEVEL=0
    run compute_dnsmasq_log_opts
    [ "$status" -eq 0 ]
    [ "$output" = "--log-queries" ]
}

@test "debug LOG_LEVEL=1 enables dnsmasq query logging" {
    LOG_LEVEL=1
    run compute_dnsmasq_log_opts
    [ "$status" -eq 0 ]
    [ "$output" = "--log-queries" ]
}

@test "invalid LOG_LEVEL does not enable dnsmasq query logging" {
    LOG_LEVEL="abc"
    run compute_dnsmasq_log_opts
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "hostapd config gets logger level lines at default" {
    run hostapd_log_lines
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "logger_syslog_level=2" ]
    [ "${lines[1]}" = "logger_stdout_level=2" ]
}

@test "hostapd config uses custom log level" {
    LOG_LEVEL=0
    run hostapd_log_lines
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "logger_syslog_level=0" ]
    [ "${lines[1]}" = "logger_stdout_level=0" ]
}

@test "hostapd config uses fallback level for invalid input" {
    LOG_LEVEL=9
    run hostapd_log_lines
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "logger_syslog_level=2" ]
    [ "${lines[1]}" = "logger_stdout_level=2" ]
}
