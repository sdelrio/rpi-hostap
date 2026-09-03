# shellcheck shell=bash
# Shared WPA passphrase validation logic used by wlanstart.sh and tests.
#
# passphrase_validate reads WPA_PASSPHRASE from the environment and returns
# non-zero if its length is outside the 8-63 character range required by
# WPA-PSK/SAE or if it contains newlines/carriage returns/control
# characters (which could inject hostapd.conf directives). Messages go to
# stderr.
passphrase_validate() {
    # Pin the locale so the length count and [[:cntrl:]] class behave
    # consistently (WPA counts bytes, not characters).
    local LC_ALL=C
    local len=${#WPA_PASSPHRASE}
    if [ "${len}" -lt 8 ] || [ "${len}" -gt 63 ] ; then
        echo "[Error] Invalid WPA_PASSPHRASE: must be 8-63 characters (got ${len})." >&2
        return 1
    fi

    if [[ "${WPA_PASSPHRASE}" == *$'\n'* || "${WPA_PASSPHRASE}" == *$'\r'* ]] ; then
        echo "[Error] Invalid WPA_PASSPHRASE: must not contain newlines." >&2
        return 1
    fi

    if [[ "${WPA_PASSPHRASE}" =~ [[:cntrl:]] ]] ; then
        echo "[Error] Invalid WPA_PASSPHRASE: must not contain control characters." >&2
        return 1
    fi
}
