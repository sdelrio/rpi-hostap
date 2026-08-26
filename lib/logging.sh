#!/bin/bash

# Failure reporting helpers, shared with tests.
#
# When multirun exits because one of its children died, the operator only
# sees an exit status. Since every daemon's output is prefixed with a
# "[name]" tag, the last tag seen in the captured output points at the
# daemon that most likely failed to start.

# Destination for preserved daemon logs when the container exits with a
# failure (issue #162). Each crash writes a timestamped copy under
# FAILURE_LOG_DIR (issue #199); only the newest FAILURE_LOG_KEEP copies are
# retained. An explicit FAILURE_LOG_PATH is still honored verbatim for
# backwards compatibility. All three are overridable for testing.
FAILURE_LOG_PATH="${FAILURE_LOG_PATH:-}"
FAILURE_LOG_DIR="${FAILURE_LOG_DIR:-/var/log/hostap-failures}"
FAILURE_LOG_KEEP="${FAILURE_LOG_KEEP:-5}"

# _logging_failure_log_target
#
# Print the path the daemon log should be preserved at. When an explicit
# FAILURE_LOG_PATH is set it is used as-is; otherwise a timestamped file
# inside FAILURE_LOG_DIR is chosen (with a numeric suffix if two crashes
# land in the same second).
_logging_failure_log_target() {
    local epoch target n=0
    if [ -n "${FAILURE_LOG_PATH}" ] ; then
        printf '%s' "${FAILURE_LOG_PATH}"
        return 0
    fi
    if ! mkdir -p "${FAILURE_LOG_DIR}" 2>/dev/null ; then
        return 1
    fi
    epoch="$(date +%s)"
    target="${FAILURE_LOG_DIR}/hostap-failure-${epoch}.log"
    while [ -e "${target}" ] ; do
        n=$((n + 1))
        target="${FAILURE_LOG_DIR}/hostap-failure-${epoch}-${n}.log"
    done
    printf '%s' "${target}"
}

# _logging_failure_prune
#
# Remove the oldest timestamped failure logs so at most FAILURE_LOG_KEEP
# remain. No-op when an explicit FAILURE_LOG_PATH is set.
_logging_failure_prune() {
    local old
    if [ -n "${FAILURE_LOG_PATH}" ] ; then
        return 0
    fi
    command ls -1t "${FAILURE_LOG_DIR}"/hostap-failure-*.log 2>/dev/null \
        | tail -n +"$((FAILURE_LOG_KEEP + 1))" \
        | while read -r old ; do
            rm -f "${old}"
        done
}

# logging_report_failure <exit-status> [tagged-output-log]
#
# Print a final error pointing at the likely failing daemon based on the
# last tagged line of captured daemon output. When a non-empty log is
# given, it is preserved under FAILURE_LOG_DIR so operators can inspect the
# full tagged output after exit.
logging_report_failure() {
    local status="$1"
    local log="${2:-}"
    local tag="[daemon]"
    local saved=""

    # The daemon log is written by a background tee; give it a moment to
    # flush so the preserved copy contains the full tagged output.
    if [ -n "${log}" ] ; then
        local prev=-
        local _
        for _ in 1 2 3 4 5 ; do
            [ "$(wc -c < "${log}" 2>/dev/null || echo 0)" = "${prev}" ] && break
            prev=$(wc -c < "${log}" 2>/dev/null || echo 0)
            sleep 0.1
        done
    fi

    if [ -n "${log}" ] && [ -s "${log}" ] ; then
        local last
        last=$(grep -oE '^\[[^]]+\]' "${log}" 2>/dev/null | tail -n 1)
        if [ -n "${last}" ] ; then
            tag="${last}"
        fi
        # Copy, then verify the copy matches the source size so a late
        # background-tee write that raced the copy is retried once. If the
        # destination is unwritable (bad dir, permissions), warn and carry on.
        local _try copied=1 dest
        for _try in 1 2 ; do
            if ! dest=$(_logging_failure_log_target) || ! cp "${log}" "${dest}" 2>/dev/null ; then
                echo "Warning: could not save daemon log to ${dest:-${FAILURE_LOG_DIR}}." >&2
                copied=0
                break
            fi
            [ "$(wc -c < "${log}" 2>/dev/null || echo 0)" = \
              "$(wc -c < "${dest}" 2>/dev/null || echo 0)" ] && break
            sleep 0.1
        done
        _logging_failure_prune
        [ "${copied}" = "1" ] && saved=" Full daemon log saved to ${dest}."
    fi

    echo "[Error] Container exiting (status ${status}): check ${tag} lines above for startup failure.${saved}" >&2
}
