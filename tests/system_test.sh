#!/bin/bash
#
# End-to-end system test for rpi-hostap on GitHub runners (ubuntu-latest).
# Simulates a Wi-Fi network with mac80211_hwsim (two radios: one AP, one
# station), runs the container and validates hostapd, dnsmasq, NAT,
# healthcheck and a real DHCP lease obtained over the simulated radio
# link via a wpa_supplicant-managed association.
#
# Must run as root on Linux.

set -u
PS4='+ $(date +%H:%M:%S) '
set -x

CONTAINER_NAME="rpi-hostap_systest"
IMAGE="rpi-hostap:systest"
IFACE="wlan0"
STA_IFACE="sta0"
AP_ADDR="192.168.254.1"
SUBNET="192.168.254.0"
OUTGOING="eth0"
SSID="testssid"
CHANNEL="6"
PASSPHRASE="passw0rd"

WPAS_PID=""

log() { echo "[systest] $*"; }
die() { echo "[systest][FAIL] $*" >&2; exit 1; }

need_root() {
    [ "$(id -u)" -eq 0 ] || die "must run as root"
}

cleanup() {
    log "Cleaning up..."
    save_debug_logs
    if [ -n "${WPAS_PID}" ]; then
        kill "${WPAS_PID}" 2>/dev/null || true
    fi
    pkill -f "wpa_supplicant.*${STA_IFACE}" 2>/dev/null || true
    timeout 30 docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    timeout 30 rmmod mac80211_hwsim 2>/dev/null \
        || timeout 30 modprobe -r mac80211_hwsim 2>/dev/null \
        || true
}

# Persist everything useful for post-mortem; uploaded as CI artifact.
save_debug_logs() {
    mkdir -p /tmp/systest-logs
    dmesg 2>/dev/null | tail -200 > /tmp/systest-logs/dmesg.log || true
    for f in /tmp/udhcpc.log /tmp/wpa.log /tmp/wpa.conf \
        /tmp/udhcpc-systest.script; do
        [ -f "${f}" ] && cp "${f}" /tmp/systest-logs/ 2>/dev/null || true
    done
    {
        echo "=== ip addr ==="; ip addr 2>&1
        echo "=== iw dev ==="; iw dev 2>&1
        echo "=== iw dev ${IFACE} info ==="; iw dev "${IFACE}" info 2>&1
        echo "=== iw dev ${IFACE} link ==="; iw dev "${IFACE}" link 2>&1
        echo "=== iw dev ${STA_IFACE} info ==="; iw dev "${STA_IFACE}" info 2>&1
        echo "=== iw dev ${STA_IFACE} link ==="; iw dev "${STA_IFACE}" link 2>&1
        echo "=== ss -uln ==="; ss -uln 2>&1
        echo "=== container state ==="
        docker inspect -f '{{.State.Status}} exit={{.State.ExitCode}}' \
            "${CONTAINER_NAME}" 2>&1 || true
    } > /tmp/systest-logs/state.txt 2>&1 || true
    docker logs --tail 200 "${CONTAINER_NAME}" \
        > /tmp/systest-logs/container.log 2>&1 || true
    # script runs under sudo; make logs readable by the runner user so
    # the upload-artifact step can zip them
    chmod -R go+rX /tmp/systest-logs 2>/dev/null || true
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

wireless_ifaces() {
    iw dev | awk '$1=="Interface"{print $2}'
}

setup_radio() {
    if [ ! -d /sys/module/mac80211_hwsim ] ||
        [ "$(wireless_ifaces | wc -l)" -lt 2 ]; then
        log "Loading mac80211_hwsim (2 radios: AP + station)..."
        rmmod mac80211_hwsim 2>/dev/null || true
        insmod /tmp/hwsim/mac80211_hwsim.ko radios=2 2>/dev/null \
            || modprobe mac80211_hwsim radios=2
    fi

    local count
    count=$(wireless_ifaces | wc -l)
    [ "${count}" -ge 2 ] || die "expected 2 radios, found ${count} interfaces"

    # Rename via temporary names: two interfaces cannot swap names
    # directly, and targets may be occupied by either interface.
    local i=0
    local cur
    for cur in $(wireless_ifaces); do
        ip link set "${cur}" down
        ip link set "${cur}" name "hwsim-tmp-${i}"
        i=$((i + 1))
    done
    ip link set "hwsim-tmp-0" name "${IFACE}"
    ip link set "hwsim-tmp-1" name "${STA_IFACE}"

    wireless_ifaces | grep -qx "${IFACE}" || die "failed to create ${IFACE}"
    wireless_ifaces | grep -qx "${STA_IFACE}" || die "failed to create ${STA_IFACE}"
    # Leave both interfaces down; wlanstart.sh configures the AP one.
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
    # Must run AFTER the image build (apk needs working DNS). Stopping
    # resolved also kills the runner's DNS, so repoint resolv.conf at
    # public resolvers to keep artifact uploads working.
    systemctl stop systemd-resolved.service systemd-resolved.socket 2>/dev/null || true
    printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf
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

associate_sta() {
    log "Associating station ${STA_IFACE} with SSID ${SSID}..."
    ip link set "${STA_IFACE}" up

    cat > /tmp/wpa.conf <<EOF
network={
    ssid="${SSID}"
    psk="${PASSPHRASE}"
}
EOF
    wpa_supplicant -D nl80211 -i "${STA_IFACE}" -c /tmp/wpa.conf \
        -f /tmp/wpa.log </dev/null >/dev/null 2>&1 &
    WPAS_PID=$!

    retry "association with ${SSID}" 60 -- \
        iw dev "${STA_IFACE}" link || return 1
    iw dev "${STA_IFACE}" link | head -n5 >&2
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
    log "Requesting DHCP lease via udhcpc on ${STA_IFACE}..."
    if ! timeout 120 busybox udhcpc \
        -i "${STA_IFACE}" -s /tmp/udhcpc-systest.script -n -q -t 10 -T 3 \
        </dev/null >/tmp/udhcpc.log 2>&1; then
        echo "[systest][FAIL] udhcpc did not obtain a lease" >&2
        cat /tmp/udhcpc.log >&2 || true
        return 1
    fi

    local leased
    leased=$(ip -4 addr show dev "${STA_IFACE}" |
        grep -o 'inet 192\.168\.254\.[0-9]*' | awk '{print $2}' | head -n1)
    [ -n "${leased}" ] || { echo "[systest][FAIL] no lease address found on ${STA_IFACE}" >&2; return 1; }

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
    associate_sta || die "station association failed"
    retry "end-to-end DHCP lease in 192.168.254.100-200" 90 -- assert_dhcp_lease || die "DHCP lease test failed"
    log "All system tests passed."
}

main "$@"
