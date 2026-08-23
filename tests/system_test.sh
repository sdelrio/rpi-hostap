#!/bin/bash
#
# End-to-end system test for rpi-hostap on GitHub runners (ubuntu-latest).
# Simulates a Wi-Fi radio with mac80211_hwsim, runs the container and
# validates hostapd, dnsmasq, NAT, healthcheck and a real DHCP lease
# obtained through a socat broadcast relay.
#
# Must run as root on Linux.

set -u

CONTAINER_NAME="rpi-hostap_systest"
IMAGE="rpi-hostap:systest"
IFACE="wlan0"
AP_ADDR="192.168.254.1"
SUBNET="192.168.254.0"
OUTGOING="eth0"
SSID="testssid"
CHANNEL="6"
PASSPHRASE="passw0rd"

NETNS="dhcptest"
VETH_HOST="veth-h"
VETH_CLI="veth-c"
VETH_HOST_IP="192.168.253.1"
VETH_CLI_IP="192.168.253.2"
RELAY_PORT="1067"

C2S_PID=""
S2C_PID=""

log() { echo "[systest] $*"; }
die() { echo "[systest][FAIL] $*" >&2; exit 1; }

need_root() {
    [ "$(id -u)" -eq 0 ] || die "must run as root"
}

cleanup() {
    log "Cleaning up..."
    [ -n "${C2S_PID}" ] && kill "${C2S_PID}" 2>/dev/null
    [ -n "${S2C_PID}" ] && kill "${S2C_PID}" 2>/dev/null
    ip netns del "${NETNS}" 2>/dev/null || true
    ip link del "${VETH_HOST}" 2>/dev/null || true
    ip route del 255.255.255.255/32 dev "${VETH_HOST}" 2>/dev/null || true
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    rmmod mac80211_hwsim 2>/dev/null \
        || modprobe -r mac80211_hwsim 2>/dev/null \
        || true
}
trap cleanup EXIT

retry() {
    # retry <description> <timeout_seconds> -- cmd...
    local desc="$1" timeout="$2"
    shift 3
    local deadline=$((SECONDS + timeout))
    while [ "${SECONDS}" -lt "${deadline}" ]; do
        if "$@" >/dev/null 2>&1; then
            log "OK: ${desc}"
            return 0
        fi
        sleep 2
    done
    echo "[systest][FAIL] timeout waiting for: ${desc}" >&2
    "$@" 2>&1 | tail -5 >&2 || true
    return 1
}

setup_radio() {
    if [ ! -d /sys/module/mac80211_hwsim ]; then
        log "Loading mac80211_hwsim..."
        insmod /tmp/hwsim/mac80211_hwsim.ko radios=1 2>/dev/null \
            || modprobe mac80211_hwsim radios=1
    fi

    local hwsim_iface
    hwsim_iface=$(iw dev | awk '$1=="Interface"{print $2}' | head -n1)
    [ -n "${hwsim_iface}" ] || die "no wireless interface found after loading mac80211_hwsim"

    if [ "${hwsim_iface}" != "${IFACE}" ]; then
        log "Renaming ${hwsim_iface} -> ${IFACE}"
        ip link set "${hwsim_iface}" down
        ip link set "${hwsim_iface}" name "${IFACE}"
    fi
    # Leave wlan0 down; wlanstart.sh configures it.
}

start_container() {
    log "Building image..."
    docker build -t "${IMAGE}" .

    free_dns_port

    log "Starting container..."
    docker run -d \
        --privileged \
        --net host \
        --name "${CONTAINER_NAME}" \
        -e INTERFACE="${IFACE}" \
        -e SSID="${SSID}" \
        -e CHANNEL="${CHANNEL}" \
        -e AP_ADDR="${AP_ADDR}" \
        -e SUBNET="${SUBNET}" \
        -e WPA_PASSPHRASE="${PASSPHRASE}" \
        -e OUTGOINGS="${OUTGOING}" \
        "${IMAGE}"
}

assert_processes() {
    docker exec "${CONTAINER_NAME}" pidof hostapd >/dev/null &&
        docker exec "${CONTAINER_NAME}" pidof dnsmasq >/dev/null
}

assert_addr() {
    ip -4 addr show dev "${IFACE}" | grep -q "${AP_ADDR}/24"
}

# dnsmasq binds a wildcard DHCP socket (device-filtered) unless
# bind-interfaces is set, so match port only.
assert_dhcp_bound() {
    ss -uln | grep -q ':67 '
}

# Verify AP mode + channel from the host side (no ctrl_interface needed).
assert_ap_channel() {
    iw dev "${IFACE}" info | grep -q 'type AP' &&
        iw dev "${IFACE}" info | grep -qE "channel ${CHANNEL} "
}

assert_ip_forward() {
    [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ]
}

assert_masquerade() {
    iptables -t nat -C POSTROUTING -s "${SUBNET}/24" -o "${OUTGOING}" -j MASQUERADE
}

assert_healthy() {
    [ "$(docker inspect -f '{{.State.Health.Status}}' "${CONTAINER_NAME}")" = "healthy" ]
}

free_dns_port() {
    # The container runs with --net host, so dnsmasq binds :53 in the host
    # netns. systemd-resolved's stub listener (127.0.0.53:53) would collide.
    # Must run AFTER the image build (apk needs working DNS).
    systemctl stop systemd-resolved.service systemd-resolved.socket 2>/dev/null || true
}

run_assertions() {
    local timeout=60
    log "Waiting for services (up to ${timeout}s)..."
    retry "hostapd and dnsmasq running" "${timeout}" -- assert_processes || return 1
    retry "${AP_ADDR}/24 assigned to ${IFACE}" "${timeout}" -- assert_addr || return 1
    retry "dnsmasq bound to port 67" "${timeout}" -- assert_dhcp_bound || return 1
    retry "AP enabled on ${IFACE} channel ${CHANNEL}" "${timeout}" -- assert_ap_channel || return 1
    retry "ip_forward enabled" "${timeout}" -- assert_ip_forward || return 1
    retry "MASQUERADE rule present" "${timeout}" -- assert_masquerade || return 1
    retry "container healthy" "${timeout}" -- assert_healthy || return 1
}

dump_debug() {
    echo "[systest][DEBUG] container state:" >&2
    docker inspect -f '{{.State.Status}} exit={{.State.ExitCode}}' \
        "${CONTAINER_NAME}" 2>&1 | tail -3 >&2
    echo "[systest][DEBUG] container logs:" >&2
    docker logs --tail 100 "${CONTAINER_NAME}" 2>&1 | tail -60 >&2 || true
}

setup_dhcp_client() {
    log "Setting up DHCP client netns..."
    ip netns add "${NETNS}"
    ip link add "${VETH_HOST}" type veth peer name "${VETH_CLI}"
    ip link set "${VETH_CLI}" netns "${NETNS}"
    ip addr add "${VETH_HOST_IP}/24" dev "${VETH_HOST}"
    ip link set "${VETH_HOST}" up
    ip netns exec "${NETNS}" ip addr add "${VETH_CLI_IP}/24" dev "${VETH_CLI}"
    ip netns exec "${NETNS}" ip link set "${VETH_CLI}" up
    ip netns exec "${NETNS}" ip link set lo up
    # force limited broadcasts out the client segment so the S2C relay
    # can re-inject dnsmasq replies into the netns
    ip route replace 255.255.255.255/32 dev "${VETH_HOST}"
}

start_relays() {
    # Client -> server relay: catch DHCP broadcasts arriving on any
    # interface (veth-h), forward to dnsmasq with a fixed source
    # IP:PORT so dnsmasq unicasts its reply back to the S2C relay.
    socat UDP4-RECVFROM:67,fork,reuseaddr \
        "UDP4-SENDTO:${AP_ADDR}:67,bind=${VETH_HOST_IP}:${RELAY_PORT}" &
    C2S_PID=$!

    # Server -> client relay: receive dnsmasq's unicast reply on the
    # relay port bound to veth-h and re-broadcast it into the client
    # segment from source port 67 (as a proper DHCP server would).
    socat "UDP4-RECVFROM:${RELAY_PORT},bind=${VETH_HOST_IP},reuseaddr,fork" \
        "UDP4-DATAGRAM:255.255.255.255:68,broadcast,bind=${VETH_HOST_IP}:67" &
    S2C_PID=$!

    sleep 1
    kill -0 "${C2S_PID}" 2>/dev/null || die "client->server relay failed to start"
    kill -0 "${S2C_PID}" 2>/dev/null || die "server->client relay failed to start"
}

dhcp_lease_script() {
    cat > /tmp/udhcpc-systest.script <<'EOF'
#!/bin/sh
case "$1" in
    bound|renew)
        ip addr flush dev "$interface"
        ip addr add "$ip/${mask:-24}" dev "$interface"
        ;;
    deconfig)
        ip addr flush dev "$interface"
        ;;
esac
exit 0
EOF
    chmod +x /tmp/udhcpc-systest.script
}

assert_dhcp_lease() {
    dhcp_lease_script
    log "Requesting DHCP lease via udhcpc in ${NETNS}..."
    if ! ip netns exec "${NETNS}" busybox udhcpc \
        -i "${VETH_CLI}" -s /tmp/udhcpc-systest.script -n -q -t 10 -T 3; then
        echo "[systest][FAIL] udhcpc did not obtain a lease" >&2
        return 1
    fi

    local leased
    leased=$(ip netns exec "${NETNS}" ip -4 addr show dev "${VETH_CLI}" |
        grep -o 'inet 192\.168\.254\.[0-9]*' | awk '{print $2}' | head -n1)
    [ -n "${leased}" ] || { echo "[systest][FAIL] no lease address found on ${VETH_CLI}" >&2; return 1; }

    log "Leased address: ${leased}"
    local last_octet
    last_octet=$(echo "${leased}" | awk -F. '{print $4}')
    [ "${last_octet}" -ge 100 ] && [ "${last_octet}" -le 200 ]
}

main() {
    need_root
    setup_radio
    start_container
    if ! run_assertions; then
        dump_debug
        die "container assertions failed"
    fi
    setup_dhcp_client
    start_relays
    retry "end-to-end DHCP lease in 192.168.254.100-200" 90 -- assert_dhcp_lease || die "DHCP lease test failed"
    log "All system tests passed."
}

main "$@"
