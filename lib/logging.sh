#!/bin/bash

# Failure reporting helpers, shared with tests.
#
# When multirun exits because one of its children died, the operator only
# sees an exit status. Since every daemon's output is prefixed with a
# "[name]" tag, the last tag seen in the captured output points at the
# daemon that most likely failed to start.

# Destination for the preserved daemon log when the container exits with
# a failure (issue #162). Overridable for testing.
FAILURE_LOG_PATH="${FAILURE_LOG_PATH:-/var/log/hostap-failure.log}"

# report_failure <exit-status> [tagged-output-log]
#
# Print a final error pointing at the likely failing daemon based on the
# last tagged line of captured daemon output. When a non-empty log is
# given, it is preserved at FAILURE_LOG_PATH so operators can inspect the
# full tagged output after exit.
report_failure() {
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
        local _try copied=1
        for _try in 1 2 ; do
            if ! cp "${log}" "${FAILURE_LOG_PATH}" 2>/dev/null ; then
                echo "Warning: could not save daemon log to ${FAILURE_LOG_PATH}." >&2
                copied=0
                break
            fi
            [ "$(wc -c < "${log}" 2>/dev/null || echo 0)" = \
              "$(wc -c < "${FAILURE_LOG_PATH}" 2>/dev/null || echo 0)" ] && break
            sleep 0.1
        done
        [ "${copied}" = "1" ] && saved=" Full daemon log saved to ${FAILURE_LOG_PATH}."
    fi

    echo "[Error] Container exiting (status ${status}): check ${tag} lines above for startup failure.${saved}" >&2
}
