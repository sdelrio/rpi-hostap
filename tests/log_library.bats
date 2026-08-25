#!/usr/bin/env bats

# Tests exercise log() and friends from lib/log.sh — the exact code used
# by scripts sourcing the library.

LIB="${BATS_TEST_DIRNAME}/../lib/log.sh"

setup() {
    unset LOG_LEVEL LOG_FILE NO_COLOR
    # Force TTY detection off so default expectations are plain text; tests
    # that need colors set FORCE_COLOR explicitly.
    export NO_COLOR=1
}

load_lib() {
    . "${LIB}"
}

@test "sourcing is clean under set -euo pipefail" {
    run bash -c 'set -euo pipefail; source ./lib/log.sh'
    [ "$status" -eq 0 ]
}

@test "log debug emits to stdout with DEBUG level" {
    load_lib
    run bash -c "set -euo pipefail; source '${LIB}'; log debug 'hello debug'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DEBUG]"* ]]
    [[ "$output" == *"hello debug" ]]
}

@test "log info emits to stdout with INFO level" {
    load_lib
    run bash -c "set -euo pipefail; source '${LIB}'; log info 'hello info'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"hello info" ]]
}

@test "log warn emits to stderr with WARN level" {
    load_lib
    run bash -c "set -euo pipefail; source '${LIB}'; log warn 'careful' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]]
    [[ "$output" == *"careful" ]]
}

@test "warn goes to stderr not stdout" {
    load_lib
    out=$(log warn "to stderr" 2>/dev/null)
    err=$(log warn "to stderr" 2>&1 >/dev/null)
    [ -z "${out}" ]
    [ -n "${err}" ]
}

@test "info goes to stdout not stderr" {
    load_lib
    out=$(log info "to stdout" 2>/dev/null)
    err=$(log info "to stdout" 2>&1 >/dev/null)
    [ -n "${out}" ]
    [ -z "${err}" ]
}

@test "log error emits to stderr with ERROR level" {
    load_lib
    run bash -c "set -euo pipefail; source '${LIB}'; log error 'bad thing' 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
    [[ "$output" == *"bad thing" ]]
}

@test "log fatal returns non-zero status" {
    load_lib
    run bash -c "set -euo pipefail; source '${LIB}'; log fatal 'doomed'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"[FATAL]"* ]]
    [[ "$output" == *"doomed" ]]
}

@test "critical alias maps to FATAL label" {
    load_lib
    run bash -c "source '${LIB}'; log critical 'boom' 2>&1"
    [[ "$output" == *"[FATAL]"* ]]
}

@test "warning alias maps to WARN label" {
    load_lib
    run bash -c "source '${LIB}'; log warning 'meh' 2>&1"
    [[ "$output" == *"[WARN]"* ]]
}

@test "LOG_LEVEL threshold filters lower levels" {
    load_lib
    run bash -c "source '${LIB}'; LOG_LEVEL=WARN; log debug 'nope'; log info 'nope too'; log warn 'yes' 2>&1; true"
    [ "$status" -eq 0 ]
    ! [[ "$output" == *"nope"* ]]
    [[ "$output" == *"[WARN]"* ]]
    [[ "$output" == *"yes" ]]
}

@test "LOG_LEVEL=ERROR mutes info and warn" {
    load_lib
    run bash -c "source '${LIB}'; LOG_LEVEL=ERROR; log info 'quiet'; log warn 'quiet too' 2>&1; true"
    ! [[ "$output" == *"quiet"* ]]
}

@test "LOG_LEVEL=DEBUG allows everything" {
    load_lib
    run bash -c "source '${LIB}'; LOG_LEVEL=DEBUG; log debug 'd'; log info 'i' 2>&1; true"
    [[ "$output" == *"d"* ]]
    [[ "$output" == *"i"* ]]
}

@test "unknown LOG_LEVEL falls back to showing everything" {
    load_lib
    run bash -c "source '${LIB}'; LOG_LEVEL=BANANA; log info 'still visible' 2>&1; true"
    [[ "$output" == *"still visible"* ]]
}

@test "output matches structured format [timestamp] [LEVEL] [script/pid] message" {
    load_lib
    local line
    line=$(NO_COLOR=1 log info "structured" 2>/dev/null)
    local re='^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[^]]*\] \[INFO\] \[[^]/]+/[0-9]+\] structured$'
    # shellcheck disable=SC2154
    [[ "${line}" =~ ${re} ]] || {
        echo "unexpected line: ${line}" >&2
        return 1
    }
}

@test "message with multiple words is preserved" {
    load_lib
    line=$(log info "one two three" 2>/dev/null)
    [[ "${line}" == *" one two three" ]]
}

@test "NO_COLOR suppresses ANSI escapes" {
    load_lib
    line=$(log info "plain" 2>/dev/null)
    ! [[ "${line}" == $'\033'* ]]
}

@test "non-TTY output has no ANSI escapes" {
    unset NO_COLOR
    run bash -c "source '${LIB}'; log info 'redirected'"
    ! [[ "$output" == *$'\033'* ]]
}

@test "LOG_FILE routes records to a file" {
    load_lib
    local logfile="${BATS_TEST_TMPDIR}/log-test.log"
    LOG_FILE="${logfile}" log info "to file"
    run cat "${logfile}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"to file" ]]
}

@test "LOG_FILE output contains no ANSI escapes" {
    load_lib
    local logfile="${BATS_TEST_TMPDIR}/log-plain.log"
    NO_COLOR= LOG_FILE="${logfile}" log error "plain file"
    run cat "${logfile}"
    ! [[ "$output" == *$'\033'* ]]
}

@test "LOG_FILE suppresses console output" {
    load_lib
    local logfile="${BATS_TEST_TMPDIR}/log-silent.log"
    run bash -c "source '${LIB}'; LOG_FILE='${logfile}'; log info 'filed only'; log warn 'warned too'; true"
    ! [[ "$output" == *"filed"* ]]
    ! [[ "$output" == *"warned"* ]]
}

@test "LOG_FILE still honors LOG_LEVEL threshold" {
    load_lib
    local logfile="${BATS_TEST_TMPDIR}/log-filtered.log"
    LOG_LEVEL=ERROR LOG_FILE="${logfile}" log info "filtered out"
    [ ! -s "${logfile}" ]
}

@test "colors are emitted when output is a TTY" {
    unset NO_COLOR
    if ! command -v script >/dev/null 2>&1 ; then
        skip "script(1) unavailable"
    fi
    local flag="-q"
    # util-linux script needs -e to propagate the child's exit status and
    # -c to take the command as an argument; BSD script (macOS) takes it
    # positionally instead.
    if [ "$(uname -s)" = "Linux" ] ; then
        flag="-qec"
    fi
    # shellcheck disable=SC2086
    run script ${flag} /dev/null bash -c "source '${LIB}'; log error 'colored' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\033['[0-9]* ]]
}
