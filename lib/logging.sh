#!/bin/bash

# Failure reporting helpers, shared with tests.
#
# When multirun exits because one of its children died, the operator only
# sees an exit status. Since every daemon's output is prefixed with a
# "[name]" tag, the last tag seen in the captured output points at the
# daemon that most likely failed to start.

# report_failure <exit-status> [tagged-output-log]
#
# Print a final error pointing at the likely failing daemon based on the
# last tagged line of captured daemon output.
# shellcheck disable=SC2120
report_failure() {
    local status="$1"
    local log="${2:-}"
    local tag="[daemon]"

    if [ -n "${log}" ] && [ -s "${log}" ] ; then
        local last
        last=$(grep -oE '^\[[^]]+\]' "${log}" 2>/dev/null | tail -n 1)
        if [ -n "${last}" ] ; then
            tag="${last}"
        fi
    fi

    echo "[Error] Container exiting (status ${status}): check ${tag} lines above for startup failure." >&2
}
