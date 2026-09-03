# shellcheck shell=bash
# Shared atomic config file writing used by wlanstart.sh and tests.
#
# atomic_write_config generates a file to a temporary location first and
# only moves it into place if generation succeeded. A plain redirection
# (emit_conf > /etc/hostapd.conf) truncates the target before the emit
# function runs, so a validation failure would leave an empty/partial
# config behind and break restart-with-old-config.
#
# The temp file is created in the same directory as the target so that
# mv(1) is a same-filesystem rename (atomic) rather than a cross-device
# copy, and so the final file inherits the directory's ownership.
#
# Usage: atomic_write_config <emit_function> <target_path>
# Returns non-zero if temp file creation, generation or the move fails;
# the target is left untouched on any failure.

atomic_write_config() {
    local emit_fn=$1
    local target=$2
    local tmp dir mode=644 _cleanup_done=0
    dir=$(dirname -- "${target}")
    # Match the permissions of the existing config if there is one,
    # otherwise fall back to a sane world-readable default (mktemp
    # creates files as 0600, which would tighten an existing 0644).
    if [ -e "${target}" ] ; then
        mode=$(stat -c '%a' "${target}" 2>/dev/null || stat -f '%Lp' "${target}")
    fi
    tmp=$(mktemp "${dir}/.$(basename -- "${target}").XXXXXX") || return 1
    trap 'if [ "${_cleanup_done}" -eq 0 ] && [ -f "${tmp}" ]; then rm -f "${tmp}"; fi' RETURN
    if ! "${emit_fn}" > "${tmp}" ; then
        return 1
    fi
    chmod "${mode}" "${tmp}"
    if ! mv -f "${tmp}" "${target}" ; then
        return 1
    fi
    _cleanup_done=1
}
