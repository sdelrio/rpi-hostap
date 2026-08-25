# shellcheck shell=bash
# Shared atomic config file writing used by wlanstart.sh and tests.
#
# write_atomic_config generates a file to a temporary location first and
# only moves it into place if generation succeeded. A plain redirection
# (emit_conf > /etc/hostapd.conf) truncates the target before the emit
# function runs, so a validation failure would leave an empty/partial
# config behind and break restart-with-old-config.
#
# Usage: write_atomic_config <emit_function> <target_path>
# Returns non-zero if temp file creation, generation or the move fails;
# the target is left untouched on any failure.

write_atomic_config() {
    local emit_fn=$1
    local target=$2
    local tmp
    tmp=$(mktemp) || return 1
    if ! "${emit_fn}" > "${tmp}" ; then
        rm -f "${tmp}"
        return 1
    fi
    mv "${tmp}" "${target}"
}
