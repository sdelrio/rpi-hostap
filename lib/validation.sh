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
    # Enforce the byte limit in the C locale so multibyte UTF-8
    # characters are counted per byte, matching the 802.11 limit.
    local LC_ALL=C

    if [ -z "${ssid}" ] ; then
        echo "[Error] Invalid SSID: must not be empty." >&2
        return 1
    fi

    if [ "${#ssid}" -gt 32 ] ; then
        echo "[Error] Invalid SSID: must be at most 32 bytes (got ${#ssid} bytes)." >&2
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

# validation_netmask_to_prefix converts a dotted-decimal netmask to its CIDR prefix
# length (e.g. 255.255.255.240 -> 28). The mask must be contiguous
# (255s, then optionally one partial octet, then 0s). Pure bash so it can
# be tested on macOS without network tools. Prints the prefix on stdout.
validation_netmask_to_prefix() {
    local mask=${1:-} octet prefix=0 seen_partial=0
    if ! validate_ipv4 "${mask}" ; then
        echo "[Error] Invalid netmask: '${mask}' is not a valid IPv4 address." >&2
        return 1
    fi
    for octet in ${mask//./ } ; do
        if [ "${octet}" = "255" ] && [ "${seen_partial}" -eq 0 ] ; then
            prefix=$((prefix + 8))
        elif [ "${octet}" = "0" ] ; then
            seen_partial=1
        elif [ "${seen_partial}" -eq 0 ] ; then
            # Partial octet: must be contiguous high bits (128..254)
            case "${octet}" in
                128) prefix=$((prefix + 1)) ;;
                192) prefix=$((prefix + 2)) ;;
                224) prefix=$((prefix + 3)) ;;
                240) prefix=$((prefix + 4)) ;;
                248) prefix=$((prefix + 5)) ;;
                252) prefix=$((prefix + 6)) ;;
                254) prefix=$((prefix + 7)) ;;
                *)
                    echo "[Error] Invalid netmask: '${mask}' is not a contiguous mask." >&2
                    return 1
                    ;;
            esac
            seen_partial=1
        else
            echo "[Error] Invalid netmask: '${mask}' is not a contiguous mask." >&2
            return 1
        fi
    done
    echo "${prefix}"
}

# validation_is_network_address checks that addr has all host bits zero for the
# given dotted-decimal netmask (i.e. addr & mask == addr). Pure bash.
validation_is_network_address() {
    local addr=${1:-} mask=${2:-}
    local a1 a2 a3 a4 m1 m2 m3 m4
    IFS=. read -r a1 a2 a3 a4 <<<"${addr}"
    IFS=. read -r m1 m2 m3 m4 <<<"${mask}"
    [ $(( a1 & m1 )) -eq "${a1}" ] || return 1
    [ $(( a2 & m2 )) -eq "${a2}" ] || return 1
    [ $(( a3 & m3 )) -eq "${a3}" ] || return 1
    [ $(( a4 & m4 )) -eq "${a4}" ] || return 1
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
