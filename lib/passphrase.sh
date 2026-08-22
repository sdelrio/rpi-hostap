# shellcheck shell=bash
# Shared WPA passphrase validation logic used by wlanstart.sh and tests.
#
# validate_passphrase reads WPA_PASSPHRASE from the environment and returns
# non-zero if its length is outside the 8-63 character range required by
# WPA-PSK/SAE. Messages go to stderr.
validate_passphrase() {
    local len=${#WPA_PASSPHRASE}
    if [ "${len}" -lt 8 ] || [ "${len}" -gt 63 ] ; then
        echo "[Error] Invalid WPA_PASSPHRASE: must be 8-63 characters (got ${len})." >&2
        return 1
    fi
}
