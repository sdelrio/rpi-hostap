# shellcheck shell=bash
# Secret-file inputs for SSID and WPA_PASSPHRASE (issue #232).
#
# Docker secrets and similar mechanisms mount sensitive values as files,
# so passing SSID/WPA_PASSPHRASE via -e exposes them in `docker inspect`.
# The _FILE convention lets users point at a file whose first line holds
# the value; the file path is the only thing visible in the environment.
#
# Precedence: when both VAR and VAR_FILE are set, the file wins and a
# warning is emitted so misconfigurations are not silently ignored.

secret_file_load() {
    local var=$1 file_var=$2
    local f="${!file_var:-}"
    [ -z "${f}" ] && return 0

    if [ -n "${!var:-}" ] ; then
        echo "[Warning] Both ${var} and ${file_var} are set; using value from ${file_var}." >&2
    fi

    if [ ! -r "${f}" ] ; then
        echo "[Error] ${file_var} '${f}' is not readable" >&2
        return 1
    fi

    printf -v "${var}" '%s' "$(head -n1 "${f}")"
}
