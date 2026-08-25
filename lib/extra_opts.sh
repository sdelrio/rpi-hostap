# shellcheck shell=bash
# Shared extra hostapd.conf options logic used by wlanstart.sh and tests.
#
# compute_extra_opts_lines reads HOSTAPD_EXTRA_OPTS from the environment
# (newline-separated) and prints each non-empty line, one per output
# line. Lines are appended verbatim to the end of the generated
# hostapd.conf; invalid values surface as hostapd config errors in logs.
compute_extra_opts_lines() {
    [ -n "${HOSTAPD_EXTRA_OPTS:-}" ] || return 0
    local line
    while IFS= read -r line || [ -n "${line}" ] ; do
        [ -n "${line}" ] && printf '%s\n' "${line}"
    done <<EOF2
${HOSTAPD_EXTRA_OPTS}
EOF2
    return 0
}
