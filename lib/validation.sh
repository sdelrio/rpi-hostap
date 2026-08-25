# shellcheck shell=bash
# Shared IPv4 address validation logic used by wlanstart.sh and tests.
#
# validate_ipv4 checks that its argument is a well-formed dotted-quad
# IPv4 address (four decimal octets 0-255). Pure bash so it can be
# tested on macOS without network tools.
validate_ipv4() {
    local addr=${1:-}
    local octet

    if ! [[ "${addr}" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] ; then
        return 1
    fi

    for octet in "${BASH_REMATCH[@]:1}" ; do
        # Leading zeros are ambiguous (and 08/09 break arithmetic in some shells)
        if [ "${#octet}" -gt 1 ] && [ "${octet:0:1}" = "0" ] ; then
            return 1
        fi
        if [ "${octet}" -gt 255 ] ; then
            return 1
        fi
    done
}

# validate_ssid checks that its argument is a safe SSID:
# - 1-32 bytes (802.11 limit)
# - no newlines, '#' comments, leading whitespace, or '=' (which could
#   form a new key when written into the unquoted hostapd.conf heredoc)
validate_ssid() {
    local ssid=${1:-}

    if [ -z "${ssid}" ] ; then
        echo "[Error] Invalid SSID: must not be empty." >&2
        return 1
    fi

    if [ "${#ssid}" -gt 32 ] ; then
        echo "[Error] Invalid SSID: must be at most 32 characters (got ${#ssid})." >&2
        return 1
    fi

    if [[ "${ssid}" == *$'\n'* || "${ssid}" == *$'\r'* ]] ; then
        echo "[Error] Invalid SSID: must not contain newlines." >&2
        return 1
    fi

    if [[ "${ssid}" == *"#"* || "${ssid}" == *"="* ]] ; then
        echo "[Error] Invalid SSID: must not contain '#' or '='." >&2
        return 1
    fi

    if [[ "${ssid}" =~ ^[[:space:]] || "${ssid}" =~ [[:space:]]$ ]] ; then
        echo "[Error] Invalid SSID: must not start or end with whitespace." >&2
        return 1
    fi
}

# validate_ipv4_param checks that a named parameter holds a valid IPv4
# address, printing the standard error message on failure.
validate_ipv4_param() {
    local name=${1:-} value=${2:-}
    if ! validate_ipv4 "${value}" ; then
        echo "[Error] Invalid ${name}: '${value}' is not a valid IPv4 address." >&2
        return 1
    fi
}
