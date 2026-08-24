# shellcheck shell=bash
# Shared IPv4 NAT logic used by wlanstart.sh and tests.
#
# parse_outgoings fills ints with the comma-separated OUTGOINGS interfaces.

parse_outgoings() {
    ints=()
    local -a raw
    local i
    IFS=',' read -r -a raw <<<"${OUTGOINGS}"
    for i in "${raw[@]}" ; do
        [ -n "${i}" ] && ints+=("${i}")
    done
}

# apply_nat_rules adds iptables MASQUERADE/FORWARD rules for outgoing traffic.
apply_nat_rules() {
    if [ "${OUTGOINGS}" ] ; then
        local int
        parse_outgoings
        for int in "${ints[@]}"
        do
            echo "Setting iptables for outgoing traffics on ${int}..."

            iptables -t nat -D POSTROUTING -s "${SUBNET}/24" -o "${int}" -j MASQUERADE > /dev/null 2>&1 || true
            iptables -t nat -A POSTROUTING -s "${SUBNET}/24" -o "${int}" -j MASQUERADE

            iptables -D FORWARD -i "${int}" -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            iptables -A FORWARD -i "${int}" -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT

            iptables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
            iptables -A FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT
        done
    else
        echo "Setting iptables for outgoing traffics on all interfaces..."

        iptables -t nat -D POSTROUTING -s "${SUBNET}/24" -j MASQUERADE > /dev/null 2>&1 || true
        iptables -t nat -A POSTROUTING -s "${SUBNET}/24" -j MASQUERADE

        iptables -D FORWARD -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        iptables -A FORWARD -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT

        iptables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
        iptables -A FORWARD -i "${INTERFACE}" -j ACCEPT
    fi
}

# remove_nat_rules deletes the rules added by apply_nat_rules.
remove_nat_rules() {
    echo "Removing iptables rules..."

    if [ "${OUTGOINGS}" ] ; then
        local int
        parse_outgoings
        for int in "${ints[@]}" ; do
            echo "Removing iptables for outgoing traffics on ${int}..."
            iptables -t nat -D POSTROUTING -s "${SUBNET}/24" -o "${int}" -j MASQUERADE > /dev/null 2>&1 || true
            iptables -D FORWARD -i "${int}" -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            iptables -D FORWARD -i "${INTERFACE}" -o "${int}" -j ACCEPT > /dev/null 2>&1 || true
        done
    else
        echo "Removing iptables for outgoing traffics on all interfaces..."
        iptables -t nat -D POSTROUTING -s "${SUBNET}/24" -j MASQUERADE > /dev/null 2>&1 || true
        iptables -D FORWARD -o "${INTERFACE}" -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        iptables -D FORWARD -i "${INTERFACE}" -j ACCEPT > /dev/null 2>&1 || true
    fi
}
