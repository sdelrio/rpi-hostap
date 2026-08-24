# rpi-hostap

[![Docker Image](https://img.shields.io/docker/v/sdelrio/rpi-hostap?label=DockerHub)](https://hub.docker.com/r/sdelrio/rpi-hostap)
[![GHCR](https://img.shields.io/badge/GitHub-ghcr.io/sdelrio%2Frpi--hostap-blue)](https://ghcr.io/sdelrio/rpi-hostap)
[![GitHub Release](https://img.shields.io/github/v/release/sdelrio/rpi-hostap)](https://github.com/sdelrio/rpi-hostap/releases)
[![License](https://img.shields.io/github/license/sdelrio/rpi-hostap)](LICENSE)

Lightweight Docker container that turns a Raspberry Pi into a wireless Access Point with DHCP server. Built on Alpine Linux for minimal footprint.

## Overview

Turn any Raspberry Pi with a USB WiFi dongle into a standalone Access Point. Ideal for:

- Isolated wireless networks without internet
- Portable hotspots for field devices
- Lab/development environments
- Replacing unreliable router wireless

## Prerequisites

### WiFi Adapter

Your USB WiFi adapter must support **AP mode**. Verify with:

```bash
iw list | grep -A 10 "Supported interface modes"
```

Expected output should include `* AP`.

### Firmware

Install the appropriate driver on the host. For Ralink adapters on Debian/Raspbian:

```bash
apt-get install firmware-ralink
```

> **Note:** Raspberry Pi 3/4 built-in WiFi does not require additional drivers.

### Country Code

Set your country's wireless regulations on the host:

```bash
iw reg set <COUNTRY_CODE>
```

Example for Spain:

```bash
iw reg set ES
```

### Disable wpa_supplicant

If `wpa_supplicant` is running on the host, it will conflict with the container. Stop it before running:

```bash
sudo systemctl stop wpa_supplicant
sudo systemctl disable wpa_supplicant
```

## Quick Start

1. Bring up the WiFi interface on the host:

```bash
sudo ip link set wlan0 up
sudo ip addr add 192.168.254.1/24 dev wlan0
```

2. Run the container:

```bash
docker run -d \
  --name rpi-hostap \
  --privileged \
  --net host \
  -e INTERFACE=wlan0 \
  -e SSID=MyAccessPoint \
  -e WPA_PASSPHRASE=changeme \
  -e OUTGOINGS=eth0 \
  sdelrio/rpi-hostap:latest
```

## Configuration

### Environment Variables

| Variable | Required | Description | Default |
|:--------:|:--------:|:-----------:|:-------:|
| `INTERFACE` | Yes | Wireless interface to use | — |
| `SSID` | No | Network name | `raspberry` |
| `WPA_PASSPHRASE` | No | WiFi password | `passw0rd` |
| `CHANNEL` | No | WiFi channel | `11` |
| `AP_ADDR` | No | Access point IP | `192.168.254.1` |
| `SUBNET` | No | Network subnet | `192.168.254.0` |
| `OUTGOINGS` | No | Comma-separated outgoing interfaces for NAT | All interfaces |
| `HW_MODE` | No | Hardware mode (`g` = 2.4GHz, `a` = 5GHz) | `g` |
| `DHCP_RANGE` | No | DHCP range (`start,end,mask,lease`) | Auto from SUBNET |
| `DHCP_LEASE` | No | DHCP lease time (used with default range) | `12h` |
| `MAX_STATIONS` | No | Max connected clients (`0` = unlimited) | `0` |
| `HIDE_SSID` | No | Hide SSID broadcast (`1` = hidden) | `0` |
| `AP_ISOLATION` | No | Isolate clients from each other (`1` = enabled) | `0` |
| `COUNTRY_CODE` | No | Regulatory domain (`US`/`CA`/`MX`: ch 1-11, `JP`: ch 1-14, others: ch 1-13). Sets `country_code` in hostapd.conf | `EU` |
| `WPA_VERSION` | No | WPA version: `2` = WPA2-PSK, `3` = WPA3-SAE (requires client support), `mixed` = WPA2/WPA3 transition (legacy clients allowed) | `2` |
| `IPV6` | No | Enable IPv6 RA/DHCPv6 for clients (`1` = enabled) | `0` |
| `MAC_FILTER` | No | MAC address filtering: `0` = off, `1` = allowlist (only listed MACs), `2` = denylist (listed MACs rejected). Requires `MAC_ACL_FILE` | `0` |
| `MAC_ACL_FILE` | No | Path to MAC list file (one MAC per line, mounted volume); required when `MAC_FILTER` is `1` or `2` | unset |
| `PRI_DNS` | No | Primary DNS server advertised to DHCP clients | `8.8.8.8` |
| `SEC_DNS` | No | Secondary DNS server advertised to DHCP clients | `8.8.4.4` |
| `DRIVER` | No | hostapd driver line override (e.g. `rtl871xdrv`); omit for the default `driver=nl80211`-based config | unset |
| `HT_ENABLED` | No | Enable 802.11n High Throughput (`ieee80211n=1`). Set to any non-empty value to enable; see [HT/VHT tuning](#htvht-80211nac-tuning) | unset |
| `HT_CAPAB` | No | 802.11n capabilities string (`ht_capab=` in hostapd.conf); requires `HT_ENABLED` | unset |
| `VHT_ENABLED` | No | Enable 802.11ac Very High Throughput (`ieee80211ac=1`); requires 5 GHz (`HW_MODE=a`) | unset |
| `VHT_CAPAB` | No | 802.11ac capabilities string (`vht_capab=` in hostapd.conf); requires `VHT_ENABLED` | unset |
| `HEALTHCHECK_START_PERIOD` | No | Grace period (seconds) after container start during which the healthcheck always passes. Measured from the container's own recorded start time (`/run/hostap-started`), not host uptime | `15` |
| `CTRL_INTERFACE` | No | Enable hostapd control interface (any non-empty value); allows `clients.sh` to list stations, see [Client Inspection](#client-inspection-optional) | unset |
| `CTRL_IFACE_DIR` | No | Control interface socket directory used by `clients.sh` | `/var/run/hostapd` |

#### HT/VHT (802.11n/ac) Tuning

By default the AP runs without HT/VHT (802.11n/ac disabled). To enable higher throughput:

```bash
docker run ... \
  -e HW_MODE=a -e CHANNEL=36 \
  -e HT_ENABLED=1 \
  -e HT_CAPAB="[HT40+][SHORT-GI-20][SHORT-GI-40]" \
  -e VHT_ENABLED=1 \
  -e VHT_CAPAB="[MAX-MPDU-3895][SHORT-GI-80]" \
  ...
```

Notes:

- `HT_ENABLED=1` emits `ieee80211n=1`; `HT_CAPAB` sets the optional `ht_capab=` line.
- `VHT_ENABLED=1` emits `ieee80211ac=1` and requires 5 GHz operation (`HW_MODE=a`); `VHT_CAPAB` sets the optional `vht_capab=` line.
- Capabilities depend on what your WiFi adapter supports — check `iw list` output (`HT capabilities` / `VHT capabilities`) before enabling.
- Common `ht_capab` flags: `[HT40+]`/`[HT40-]` (40 MHz channels), `[SHORT-GI-20]`, `[SHORT-GI-40]`. Common `vht_capab` flags: `[SHORT-GI-80]`, `[MAX-MPDU-3895]`, `[SU-BEAMFORMER]`.

#### MAC Address Filtering (optional)

MAC filtering is **off by default**; behavior is unchanged unless you set `MAC_FILTER`. When enabled:

- `MAC_FILTER=1` (allowlist): only MACs listed in the file can associate (`macaddr_acl=1` + `accept_mac_file=`).
- `MAC_FILTER=2` (denylist): listed MACs are rejected (`macaddr_acl=1` + `deny_mac_file=`).
- Startup fails with an error if the filter is enabled without `MAC_ACL_FILE`, and warns if the file is missing or unreadable.
- Note that MAC filtering is a weak control on its own (MACs can be spoofed); combine it with WPA2/WPA3.

```bash
docker run ... -e MAC_FILTER=1 -v /path/to/hostapd.accept:/etc/hostapd.accept:ro ...
```

File format (one MAC per line):

```
aa:bb:cc:dd:ee:ff
11:22:33:44:55:66
```

#### WPA3 (SAE)

Setting `WPA_VERSION=3` enables WPA3-SAE authentication. Note:
- Client devices must support SAE (wpa_supplicant 2.7+, iOS 13+/macOS 10.15+, Android 10+).
- Older clients that only support WPA2 will not be able to connect.

Setting `WPA_VERSION=mixed` enables WPA2/WPA3 transition mode: WPA3-SAE capable devices use SAE, while legacy WPA2 clients can still connect with WPA2-PSK. Note that transition mode is considered less secure than WPA3-only.

#### Regional Channel Validation

When `COUNTRY_CODE` is set, 2.4 GHz channels (`hw_mode=g` or `b`) are validated against regional limits:

| Region | Countries | Allowed Channels (2.4 GHz) |
|--------|-----------|---------------------------|
| North America | US, CA, MX | 1–11 |
| Europe (ETSI) | EU, UK, ES, ... (default) | 1–13 |
| Japan | JP | 1–14 |

Unknown countries fall back to the ETSI limit (1–13). A warning is emitted if `COUNTRY_CODE` is not set.

For 5 GHz (`hw_mode=a`), channels are validated against the allowed 5 GHz set:

- **Non-DFS channels** (always allowed): 36, 40, 44, 48, 149, 153, 157, 161, 165
- **DFS channels** (allowed with a radar detection/CAC warning): 52, 56, 60, 64, 100–144 (in steps of 4)
- Any other channel is rejected with a clear error.

#### Dry-Run Validation (`--validate`)

`wlanstart.sh --validate` (aliases: `-t`, `--test`) checks the configuration without touching the system:

```bash
docker run --rm \
  -e INTERFACE=wlan0 -e SSID=myap -e WPA_PASSPHRASE=supersecret -e COUNTRY_CODE=US \
  <image> --validate
```

It applies the same environment defaults as a normal start, runs every validator (channel/regulatory, passphrase, MAC filter, DHCP range, IPv4 addresses) and, on success, prints the generated `hostapd.conf` and `dnsmasq.conf` to stdout. It performs no system mutations: no interface changes, sysctls, iptables rules or daemons.

On invalid configuration it exits non-zero and lists all validation errors (not just the first). This is covered in CI by the bats suite (`tests/validate_mode.bats`).

#### Client Inspection (optional)

By default the hostapd control interface is not enabled, to keep the generated config minimal. Set `CTRL_INTERFACE` to any non-empty value to opt in:

```bash
docker run ... -e CTRL_INTERFACE=1 ...
```

This emits `ctrl_interface=/var/run/hostapd` and `ctrl_interface_group=0` into `hostapd.conf`. Once enabled, list currently associated stations from inside the container:

```bash
docker exec rpi-hostap clients.sh
```

Output includes MAC address, signal, connected time and tx/rx rates per station (as reported by `hostapd_cli all_sta`). The control interface directory can be overridden with `CTRL_IFACE_DIR` (default `/var/run/hostapd`).

### Build from Source

```bash
make run
```

## Networking

### NAT / IP Forwarding

The container enables IP forwarding at runtime. For persistence across host reboots:

```bash
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf
sudo sysctl -p
```

### IPv6 Support (optional)

IPv6 is **off by default**; behavior is unchanged unless you set `IPV6=1`. When enabled:

- `net.ipv6.conf.all.forwarding=1` is set at runtime (IPv6 forwarding).
- dnsmasq advertises SLAAC/RA with stateless DHCPv6 on the AP interface:
  `dhcp-range=::,constructor:<INTERFACE>,ra-names,stateless`
- `ip6tables` FORWARD rules mirror the IPv4 handling (established/related in, new out). There is no IPv6 NAT — clients get addresses from the upstream network's prefix via RA, or link-local/ULA otherwise.

```bash
docker run ... -e IPV6=1 ...
```

Caveats:

- Client IPv6 connectivity depends on the upstream network advertising an IPv6 prefix (Router Advertisements on the outgoing interface). Without an upstream prefix, clients will only obtain link-local addresses.
- The container sets forwarding at runtime via `/proc/sys`; for host persistence across reboots see the sysctl commands above.
- Some ISPs/hosters filter or rate-limit IPv6; test with `ping6` / `traceroute -6` from a client.

### Outgoing Interfaces

By default, NAT is applied to all outgoing interfaces. To restrict to specific interfaces (e.g., `eth0`):

```bash
-e OUTGOINGS=eth0
```

For multiple interfaces:

```bash
-e OUTGOINGS=eth0,wwan0
```

## Troubleshooting

### "Could not connect to kernel driver"

`wpa_supplicant` is using the interface. Stop it on the host:

```bash
sudo systemctl stop wpa_supplicant
```

### Container exits immediately

Check logs:

```bash
docker logs rpi-hostap
```

Ensure the WiFi interface is up and not in use by another process.

## Health Check

The container defines a Docker `HEALTHCHECK` that runs `/bin/healthcheck.sh` every 30s (15s start period, 3 retries). The check verifies, in order:

1. The container started less than `HEALTHCHECK_START_PERIOD` seconds ago (default 15s); during this grace period the check always passes. The start time is recorded by the entrypoint in `/run/hostap-started` at container boot — `/proc/uptime` is deliberately not used because inside Docker it reflects the *host's* uptime, which would disable the grace period on long-running hosts.
2. The `hostapd` process is running.
3. The `dnsmasq` process is running.
4. The wireless interface (`INTERFACE`) exists and is up.
5. If `AP_ADDR` is set: the address is actually assigned to `INTERFACE` (via `ip -4 addr show`). This catches cases where IP configuration failed after hostapd started.

If any check fails, the container is reported as `unhealthy`.

**Script grace vs Docker start-period**: there are two independent grace mechanisms. `HEALTHCHECK_START_PERIOD` (env var) controls the *script-side* grace window measured from the recorded start time. The Dockerfile's `HEALTHCHECK --start-period=15s` is the Docker-side outer bound during which failing checks do not count towards the `unhealthy` transition. If you raise the env var (e.g. `HEALTHCHECK_START_PERIOD=60`), the script keeps passing for 60s after start regardless of the Docker setting; the Dockerfile start-period only affects when Docker itself starts counting failures.

| `HEALTHCHECK_START_PERIOD` | No | Grace period (seconds) after container start during which the healthcheck always passes. Measured from the container's own recorded start time (`/run/hostap-started`), not host uptime | `15` |
Note: the AP's beaconing status itself is not verified — that would require enabling the hostapd control interface (`ctrl_interface`), available as an opt-in via `CTRL_INTERFACE` (see [Client Inspection](#client-inspection-optional)).

## Contributing

See [CI.md](CI.md) for details on the release process and versioning.

## License

See [LICENSE](LICENSE) for details.
