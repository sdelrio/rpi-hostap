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
