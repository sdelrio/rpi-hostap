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
```

The container assigns `AP_ADDR` (default `192.168.254.1/24`) to the interface itself on startup; it is configurable via the `AP_ADDR` and `DHCP_RANGE` environment variables.

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
| `INTERFACE` | Yes | Wireless interface to use | - |
| `SSID` | No | Network name | `raspberry` |
| `SSID_FILE` | No | Path to a file whose first line holds the SSID (Docker secrets `_FILE` convention). Overrides `SSID` when both are set. See [Secret-file inputs](docs/configuration.md#secret-file-inputs-optional) | unset |
| `WPA_PASSPHRASE` | No | WiFi password (8-63 characters; newlines and control characters are rejected) | `passw0rd` |
| `WPA_PASSPHRASE_FILE` | No | Path to a file whose first line holds the WPA passphrase (Docker secrets `_FILE` convention). Overrides `WPA_PASSPHRASE` when both are set. See [Secret-file inputs](docs/configuration.md#secret-file-inputs-optional) | unset |
| `CHANNEL` | No | WiFi channel, or `acs` for automatic channel selection (requires driver support; startup may be delayed while scanning, and the `HEALTHCHECK_START_PERIOD` grace period applies since ACS can land on DFS/radar channels) | `11` |
| `AP_ADDR` | No | Access point IP | `192.168.254.1` |
| `SUBNET` | No | Network subnet | `192.168.254.0` |
| `OUTGOINGS` | No | Comma-separated outgoing interfaces for NAT | All interfaces |
| `HW_MODE` | No | Hardware mode (`g` = 2.4GHz, `a` = 5GHz) | `g` |
| `DHCP_RANGE` | No | DHCP range (`start,end,mask,lease`). The `mask` field sets the subnet prefix used on the AP interface and NAT rules (e.g. `255.255.255.240` = `/28`) | Auto from SUBNET |
| `DHCP_LEASE` | No | DHCP lease time (used with default range) | `12h` |
| `MAX_STATIONS` | No | Max connected clients (`0` = unlimited) | `0` |
| `TX_POWER` | No | Transmit power: integer dBm (fixed, e.g. `20`) or `auto`. Unset leaves the driver default. Must respect `COUNTRY_CODE` regulatory limits; startup is fatal if the value cannot be applied. See [Transmit Power](docs/configuration.md#transmit-power-optional) | unset |
| `HIDE_SSID` | No | Hide SSID broadcast (`1` = hidden) | `0` |
| `AP_ISOLATION` | No | Isolate clients from each other (`1` = enabled) | `0` |
| `COUNTRY_CODE` | No | Regulatory domain (`US`/`CA`/`MX`: ch 1-11, `JP`: ch 1-14, others: ch 1-13). Sets `country_code` in hostapd.conf | `EU` |
| `WPA_VERSION` | No | WPA version: `2` = WPA2-PSK, `3` = WPA3-SAE (requires client support), `mixed` = WPA2/WPA3 transition (legacy clients allowed) | `2` |
| `PMF` | No | Protected Management Frames / 802.11w (`ieee80211w=`): `0` = disabled, `1` = optional, `2` = required. Overrides the WPA-derived default (`2` for `WPA_VERSION=3`, `1` for `mixed`, none for `2`); `0` is rejected with `WPA_VERSION=3`. See [PMF](docs/configuration.md#pmf-80211w) | unset |
| `IPV6` | No | Enable IPv6 RA/DHCPv6 for clients (`1` = enabled) | `0` |
| `MAC_FILTER` | No | MAC address filtering: `0` = off, `1` = allowlist (only listed MACs), `2` = denylist (listed MACs rejected). Requires `MAC_ACL_FILE` | `0` |
| `MAC_ACL_FILE` | No | Path to MAC list file (one MAC per line, mounted volume); required when `MAC_FILTER` is `1` or `2` | unset |
| `PRI_DNS` | No | Primary DNS server advertised to DHCP clients. Must be a valid IPv4 address (dotted quad, e.g. `8.8.8.8`) | `8.8.8.8` |
| `SEC_DNS` | No | Secondary DNS server advertised to DHCP clients. Must be a valid IPv4 address (dotted quad, e.g. `8.8.4.4`) | `8.8.4.4` |
| `DRIVER` | No | hostapd driver line override (e.g. `rtl871xdrv`); omit for the default `driver=nl80211`-based config | unset |
| `HT_ENABLED` | No | Enable 802.11n High Throughput (`ieee80211n=1`). Set to any non-empty value to enable; see [HT/VHT tuning](docs/configuration.md#htvht-80211nac-tuning) | unset |
| `HT_CAPAB` | No | 802.11n capabilities string (`ht_capab=` in hostapd.conf); requires `HT_ENABLED` | unset |
| `VHT_ENABLED` | No | Enable 802.11ac Very High Throughput (`ieee80211ac=1`); requires 5 GHz (`HW_MODE=a`) | unset |
| `VHT_CAPAB` | No | 802.11ac capabilities string (`vht_capab=` in hostapd.conf); requires `VHT_ENABLED` | unset |
| `HOSTAPD_EXTRA_OPTS` | No | Extra hostapd.conf lines, newline-separated, appended verbatim after all generated lines. Unvalidated: invalid values surface as hostapd config errors in logs (e.g. `"auth_algs=3\nbeacon_int=100"`) | unset |
| `HEALTHCHECK_START_PERIOD` | No | Grace period (seconds) after container start during which the healthcheck always passes. Measured from the container's own recorded start time (`/run/hostap-started`), not host uptime; see [Health Check](docs/healthcheck.md) and [Script grace vs Docker start-period](docs/healthcheck.md#script-grace-vs-docker-start-period). Note: this only extends the script-side grace window - Docker's own `--start-period` stays baked at 15s in the image, so failures after the script grace but during slow bring-up (e.g. DFS CAC) count toward Docker's retries; override with `--health-start-period` or compose `start_period` | `15` |
| `CTRL_INTERFACE` | No | Enable hostapd control interface (any non-empty value); allows `clients.sh` to list stations, see [Client Inspection](docs/operations.md#client-inspection-optional) | unset |
| `CTRL_IFACE_DIR` | No | Control interface socket directory used by `clients.sh` | `/var/run/hostapd` |
| `HEALTHCHECK_DEEP` | No | Opt-in deep healthcheck verifying the AP is actually beaconing via `hostapd_cli status`; see [Deep Healthcheck](docs/healthcheck.md#deep-healthcheck-optional) | unset |
| `HEALTHCHECK_MIN_STATIONS` | No | Minimum number of associated stations required by the healthcheck (fails with expected vs actual count below the threshold). Opt-in; requires the control interface (`CTRL_INTERFACE` or `HEALTHCHECK_DEEP`). Note the DFS/CAC caveat in [docs/healthcheck.md](docs/healthcheck.md) | unset |
| `HEALTHCHECK_STARTED_FILE` | No | Path to the file where the entrypoint records the container start time used by the healthcheck grace period (internal/testing hook) | `/run/hostap-started` |
| `FAILURE_LOG_DIR` | No | Directory where daemon logs are preserved on crash; see [Preserved failure logs](docs/troubleshooting.md#preserved-failure-logs) | `/var/log/hostap-failures` |
| `FAILURE_LOG_KEEP` | No | Number of crash logs retained (oldest pruned); see [Preserved failure logs](docs/troubleshooting.md#preserved-failure-logs) | `5` |
| `FAILURE_LOG_PATH` | No | Explicit path for the preserved log (overrides dir/keep, no rotation); see [Preserved failure logs](docs/troubleshooting.md#preserved-failure-logs) | unset |

Detailed topics and examples are split across the [docs/](docs/INDEX.md) folder: radio/security topics in [docs/configuration.md](docs/configuration.md), config validation in [docs/validation.md](docs/validation.md), and runtime diagnostics in [docs/operations.md](docs/operations.md).

### Full-Featured Example

A complete `docker run` combining every option group (5 GHz 802.11ac, WPA3 transition mode, MAC allowlist, hidden SSID, client isolation, IPv6, restricted NAT, deep healthcheck with [DFS](https://en.wikipedia.org/wiki/Dynamic_frequency_selection)-safe grace period):

```bash
docker run -d \
  --name rpi-hostap \
  --privileged \
  --net host \
  --restart unless-stopped \
  -e INTERFACE=wlan0 \
  -e SSID=MyAccessPoint \
  -e WPA_PASSPHRASE=changeme \
  -e HW_MODE=a -e CHANNEL=36 \
  -e HT_ENABLED=1 \
  -e HT_CAPAB="[HT40+][SHORT-GI-20][SHORT-GI-40]" \
  -e VHT_ENABLED=1 \
  -e VHT_CAPAB="[MAX-MPDU-3895][SHORT-GI-80]" \
  -e COUNTRY_CODE=US \
  -e WPA_VERSION=mixed \
  -e MAC_FILTER=1 \
  -v /path/to/hostapd.accept:/etc/hostapd.accept:ro \
  -e HIDE_SSID=1 \
  -e AP_ISOLATION=1 \
  -e IPV6=1 \
  -e OUTGOINGS=eth0 \
  -e HEALTHCHECK_DEEP=1 \
  -e HEALTHCHECK_START_PERIOD=90 \
  sdelrio/rpi-hostap:latest
```

Each option group is explained in the docs: [HT/VHT tuning](docs/configuration.md#htvht-80211nac-tuning), [WPA3/SAE](docs/configuration.md#wpa3-sae), [MAC filtering](docs/configuration.md#mac-address-filtering-optional), [IPv6](docs/networking.md#ipv6-support-optional), [deep healthcheck](docs/healthcheck.md#deep-healthcheck-optional).

### Build from Source

```bash
make run
```

## Networking

The container enables NAT/IP forwarding at runtime, optionally restricted to specific outgoing interfaces, with optional IPv6 support. See [docs/networking.md](docs/networking.md) for details.

## Troubleshooting

Common issues (kernel driver conflicts, containers exiting immediately) are covered in [docs/troubleshooting.md](docs/troubleshooting.md).

## Health Check

The container runs a Docker healthcheck every 30s verifying that `hostapd`, `dnsmasq`, the wireless interface and IP assignment are healthy, with an optional deep check via `hostapd_cli`. See [docs/healthcheck.md](docs/healthcheck.md) for details.

## Documentation

Project requirements are defined in [SPEC.md](SPEC.md). All detailed documentation lives in the [docs/](docs/INDEX.md) folder - see its index for the full list of topics.

## Contributing

See [CI.md](CI.md) for details on the release process and versioning.

## License

See [LICENSE](LICENSE) for details.
