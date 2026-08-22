#!/bin/bash

cleanup() {
    echo "Shutting down..."
    kill "${HOSTAPD_PID}" 2>/dev/null
    kill "${DNSMASQ_PID}" 2>/dev/null
    wait "${HOSTAPD_PID}" 2>/dev/null
    wait "${DNSMASQ_PID}" 2>/dev/null

    echo "Removing iptables rules..."

    if [ "${OUTGOINGS}" ] ; then
        ints="$(sed 's/,\+/ /g' <<<"${OUTGOINGS}")"
        for int in ${ints} ; do
            echo "Removing iptables for outgoing traffics on ${int}..."
            iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -o ${int} -j MASQUERADE > /dev/null 2>&1 || true
            iptables -D FORWARD -i ${int} -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
            iptables -D FORWARD -i ${INTERFACE} -o ${int} -j ACCEPT > /dev/null 2>&1 || true
        done
    else
        echo "Removing iptables for outgoing traffics on all interfaces..."
        iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -j MASQUERADE > /dev/null 2>&1 || true
        iptables -D FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
        iptables -D FORWARD -i ${INTERFACE} -j ACCEPT > /dev/null 2>&1 || true
    fi

    exit 0
}

trap cleanup SIGINT SIGTERM SIGHUP

# Check if running in privileged mode
if [ ! -w "/sys" ] ; then
    echo "[Error] Not running in privileged mode."
    exit 1
fi

# Check environment variables
if [ ! "${INTERFACE}" ] ; then
    echo "[Error] An interface must be specified."
    exit 1
fi

# Default values
true ${SUBNET:=192.168.254.0}
true ${AP_ADDR:=192.168.254.1}
true ${PRI_DNS:=8.8.8.8}
true ${SEC_DNS:=8.8.4.4}
true ${SSID:=raspberry}
true ${CHANNEL:=11}
true ${WPA_PASSPHRASE:=passw0rd}
true ${HW_MODE:=g}
true ${MAX_STATIONS:=0}

# Startup warnings for default credentials
if [ "${SSID}" = "raspberry" ] ; then
    echo "[Warning] Using default SSID 'raspberry'. Set SSID env var for production."
fi
if [ "${WPA_PASSPHRASE}" = "passw0rd" ] ; then
    echo "[Warning] Using default WPA passphrase. Set WPA_PASSPHRASE env var for production."
fi
if [ "${MAX_STATIONS}" != "0" ] && ! [ "${MAX_STATIONS}" -gt 0 ] 2>/dev/null ; then
    echo "[Warning] Invalid MAX_STATIONS '${MAX_STATIONS}'. Must be a non-negative integer. Ignoring."
fi

_MAX_STA_CONF=""
if [ "${MAX_STATIONS}" -gt 0 ] 2>/dev/null ; then
    _MAX_STA_CONF="max_num_sta=${MAX_STATIONS}"
fi

if [ ! -f "/etc/hostapd.conf" ] ; then
    cat > "/etc/hostapd.conf" <<EOF
interface=${INTERFACE}
${DRIVER+"driver=${DRIVER}"}
ssid=${SSID}
${HIDE_SSID+"ssid_hidden=${HIDE_SSID}"}
hw_mode=${HW_MODE}
channel=${CHANNEL}
wpa=2
wpa_passphrase=${WPA_PASSPHRASE}
wpa_key_mgmt=WPA-PSK
# TKIP is no secure anymore
#wpa_pairwise=TKIP CCMP
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_ptk_rekey=600
wmm_enabled=1
${_MAX_STA_CONF}
${AP_ISOLATION+"ap_isolate=${AP_ISOLATION}"}

# Activate channel selection for HT High Througput (802.11an)

${HT_ENABLED+"ieee80211n=1"}
${HT_CAPAB+"ht_capab=${HT_CAPAB}"}

# Activate channel selection for VHT Very High Througput (802.11ac)

${VHT_ENABLED+"ieee80211ac=1"}
${VHT_CAPAB+"vht_capab=${VHT_CAPAB}"}
EOF

fi

# Setup interface and restart DHCP service
ip link set ${INTERFACE} up
ip addr flush dev ${INTERFACE}
ip addr add ${AP_ADDR}/24 dev ${INTERFACE}

# NAT settings
echo "NAT settings ip_dynaddr, ip_forward"


for i in ip_dynaddr ip_forward ; do
  if [ $(cat /proc/sys/net/ipv4/$i) -eq 1 ] ; then
    echo $i already 1
  else
    echo "1" > /proc/sys/net/ipv4/$i
  fi
done

cat /proc/sys/net/ipv4/ip_dynaddr
cat /proc/sys/net/ipv4/ip_forward

if [ "${OUTGOINGS}" ] ; then
   ints="$(sed 's/,\+/ /g' <<<"${OUTGOINGS}")"
   for int in ${ints}
   do
      echo "Setting iptables for outgoing traffics on ${int}..."

      iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -o ${int} -j MASQUERADE > /dev/null 2>&1 || true
      iptables -t nat -A POSTROUTING -s ${SUBNET}/24 -o ${int} -j MASQUERADE

      iptables -D FORWARD -i ${int} -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
      iptables -A FORWARD -i ${int} -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT

      iptables -D FORWARD -i ${INTERFACE} -o ${int} -j ACCEPT > /dev/null 2>&1 || true
      iptables -A FORWARD -i ${INTERFACE} -o ${int} -j ACCEPT
   done
else
   echo "Setting iptables for outgoing traffics on all interfaces..."

   iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -j MASQUERADE > /dev/null 2>&1 || true
   iptables -t nat -A POSTROUTING -s ${SUBNET}/24 -j MASQUERADE

   iptables -D FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
   iptables -A FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT

   iptables -D FORWARD -i ${INTERFACE} -j ACCEPT > /dev/null 2>&1 || true
   iptables -A FORWARD -i ${INTERFACE} -j ACCEPT
fi

echo "Configuring DHCP server .."

# Default DHCP lease time
true ${DHCP_LEASE:=12h}

# Compute default DHCP range if not set
if [ -z "${DHCP_RANGE}" ] ; then
    SUBNET_PREFIX=$(echo $SUBNET | rev | cut -d. -f2- | rev)
    DHCP_RANGE="${SUBNET_PREFIX}.100,${SUBNET_PREFIX}.200,255.255.255.0,${DHCP_LEASE}"
    echo "[Warning] DHCP_RANGE not set, using default: $DHCP_RANGE"
else
    # Validate DHCP_RANGE format: must contain exactly 3 commas (start_ip,end_ip,netmask,lease)
    COMMA_COUNT=$(echo "${DHCP_RANGE}" | tr -cd ',' | wc -c)
    if [ "${COMMA_COUNT}" -ne 3 ] ; then
        echo "[Error] Invalid DHCP_RANGE format: '${DHCP_RANGE}'"
        echo "  Expected: start_ip,end_ip,netmask,lease_time"
        echo "  Example: 192.168.254.100,192.168.254.200,255.255.255.0,12h"
        exit 1
    fi
fi

cat > "/etc/dnsmasq.conf" <<EOF
interface=${INTERFACE}
dhcp-range=${DHCP_RANGE}
dhcp-option=option:router,${AP_ADDR}
dhcp-option=option:dns-server,${PRI_DNS},${SEC_DNS}
EOF

echo "Starting dnsmasq daemon ..."
dnsmasq --no-daemon &
DNSMASQ_PID=$!

if ! kill -0 "${DNSMASQ_PID}" 2>/dev/null ; then
    echo "[Error] dnsmasq failed to start."
    exit 1
fi

echo "Starting HostAP daemon ..."
/usr/sbin/hostapd /etc/hostapd.conf &
HOSTAPD_PID=$!

if ! kill -0 "${HOSTAPD_PID}" 2>/dev/null ; then
    echo "[Error] hostapd failed to start."
    kill "${DNSMASQ_PID}" 2>/dev/null
    exit 1
fi

wait "${DNSMASQ_PID}" "${HOSTAPD_PID}"
