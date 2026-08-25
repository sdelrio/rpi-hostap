# rpi-hostap Specification

This document defines the requirements of the rpi-hostap project. It is the
reference for what the project must do; the [README](README.md) and
[docs/INDEX.md](docs/INDEX.md) explain how to use it.

## 1. Purpose

rpi-hostap turns a Raspberry Pi (with an AP-mode capable WiFi adapter, typically
a USB dongle) into a standalone wireless Access Point running inside a Docker
container. The container provides:

- A hostapd-based wireless AP (configurable SSID, channel, security).
- DHCP address assignment to clients via dnsmasq.
- Optional NAT so clients can reach upstream networks through the Pi.
- Operational tooling: container healthcheck, dry-run config validation and
  client inspection.

It runs on Alpine Linux for minimal footprint.

## 2. Functional Requirements

### 2.1 Radio configuration

- The AP interface is selected via `INTERFACE` (required in normal mode).
- `SSID` (default `raspberry`) sets the network name.
- `HW_MODE` selects the band (`g` = 2.4 GHz default, `a` = 5 GHz); `CHANNEL`
  (default `11`) sets the channel.
- `COUNTRY_CODE` (default `EU`, warning emitted when unset) sets the regulatory
  domain via `country_code=` in hostapd.conf.
- Channel validation: channels are validated against the regulatory domain
  (`US`/`CA`/`MX`: 1-11, `JP`: 1-14, others: 1-13) and hardware mode.
- Optional 802.11n (`HT_ENABLED`, `HT_CAPAB`) and 802.11ac (`VHT_ENABLED`,
  `VHT_CAPAB`; requires `HW_MODE=a`) High Throughput tuning lines.
- An optional `DRIVER` override replaces the default nl80211 driver line
  (e.g. for Realtek adapters needing `rtl871xdrv`).
- Optional hidden SSID (`HIDE_SSID=1`), client limit (`MAX_STATIONS`, `0` =
  unlimited) and client isolation (`AP_ISOLATION=1`).

### 2.2 Security / WPA

- `WPA_PASSPHRASE` (default `passw0rd`, warning emitted for default
  credentials) configures WPA2-PSK by default.
- `WPA_VERSION` selects: `2` = WPA2-PSK (default), `3` = WPA3-SAE, `mixed` =
  WPA2/WPA3 transition mode.
- Passphrase length is validated against hostapd requirements (8-63 chars).
- Generated `hostapd.conf` includes `wpa_ptk_rekey=600` and `wmm_enabled=1`.

### 2.3 MAC filtering

- `MAC_FILTER`: `0` = off (default), `1` = allowlist (only listed MACs may
  associate), `2` = denylist (listed MACs rejected).
- Requires `MAC_ACL_FILE` pointing to a file with one MAC per line (typically
  mounted read-only from the host); startup/validation fails when the filter is
  enabled but `MAC_ACL_FILE` is unset. A warning is emitted (not fatal) if the
  file itself is missing or unreadable.

### 2.4 DHCP

- dnsmasq serves DHCP on the AP interface.
- `DHCP_RANGE` may be given as `start,end,mask,lease`; otherwise it is derived
  automatically from `SUBNET` (default `192.168.254.0`) with `DHCP_LEASE`
  (default `12h`).
- Clients are told the router (`AP_ADDR`, default `192.168.254.1`) and DNS
  servers (`PRI_DNS` default `8.8.8.8`, `SEC_DNS` default `8.8.4.4`).

### 2.5 NAT

- IPv4 forwarding and `ip_dynaddr` sysctls are enabled at runtime.
- iptables MASQUERADE rules provide NAT; `OUTGOINGS` restricts masquerading to
  specific comma-separated outgoing interfaces, otherwise all interfaces.
- All applied iptables/ip6tables rules are removed on shutdown (see §3.3).

### 2.6 IPv6 (optional)

- Enabled with `IPV6=1` (default off).
- Enables IPv6 forwarding and applies ip6tables rules mirroring the IPv4 NAT
  behavior.
- dnsmasq advertises RA/DHCPv6 to clients when enabled.

### 2.7 Healthcheck

- Docker healthcheck runs every 30s (5s timeout, 3 retries) via
  `healthcheck.sh`.
- Grace period (`HEALTHCHECK_START_PERIOD`, default 15s) during which checks
  always pass; measured from the container's own recorded start time
  (`/run/hostap-started`), not host uptime, since `/proc/uptime` reflects the
  host in Docker.
- Checks after grace period: hostapd running, dnsmasq running, wireless
  interface exists and is in state UP, and `AP_ADDR` assigned to the interface.
- Deep check (`HEALTHCHECK_DEEP`): verifies hostapd reports `state=ENABLED`
  via `hostapd_cli status` (requires control interface enabled). Useful with
  DFS channels where CAC can delay beaconing (raise the start period, e.g. 90).

### 2.8 Validate mode

- `wlanstart.sh --validate` (also `-t`/`--test`) performs a full dry run:
  applies env defaults, runs all validators (interface presence, channel vs
  regulatory domain/hw mode, IPv4 syntax of `SUBNET`/`AP_ADDR`, passphrase,
  MAC filter setup) collecting all failures rather than stopping at the first,
  then prints the generated `hostapd.conf` and `dnsmasq.conf` to stdout.
- Never touches interfaces, sysctls or firewall state in this mode.
- Unknown options cause a usage error with exit code 1.

### 2.9 clients.sh

- `clients.sh` lists stations currently associated with the AP via
  `hostapd_cli all_sta`.
- Requires `CTRL_INTERFACE` set (which enables `ctrl_interface` in
  hostapd.conf) and `INTERFACE`; socket directory defaults to
  `/var/run/hostapd` (`CTRL_IFACE_DIR`).

## 3. Non-functional Requirements

### 3.1 Reproducible builds

- apk packages in the Dockerfile are pinned to exact versions
  (`bash=...`, `hostapd=...`, etc.) and the base image is pinned
  (`alpine:3.24.1`). This is deliberate: builds must be reproducible.
  Do not loosen these pins; dependency bumps go through Renovate
  (`renovate.json`), which opens PRs that update pins deliberately.

### 3.2 Privileged mode + host networking

- The container requires `--privileged` and `--net host`: it must manipulate
  host wireless interfaces, write sysctls and manage iptables/nftables rules.
- Normal mode verifies privileged access at startup (writability of `/sys`)
  and exits with an error otherwise.
- Host prerequisites (documented in README): AP-mode capable adapter with host
  driver/firmware installed, `iw reg set` country code, and wpa_supplicant
  disabled to avoid driver conflicts.

### 3.3 Graceful teardown guarantees

- On SIGINT/SIGTERM/SIGHUP the entrypoint forwards the signal to multirun
  (which relays to hostapd/dnsmasq), waits for children to exit, then tears
  down exactly once.
- Teardown removes all NAT rules added at startup, removes ip6tables rules if
  IPv6 was enabled, and tears down the configured interface. No leftover
  iptables/interface state may remain after the container exits.
- Signals arriving before daemons start still trigger cleanup and a clean
  exit 0.
- If a daemon dies unexpectedly, the container exits non-zero with a failure
  report attributing which daemon failed (tagged `[hostapd]`/`[dnsmasq]` log
  prefixes).

## 4. Explicit Non-goals

The following are out of scope:

- Multi-BSS (multiple SSIDs/virtual APs from one radio).
- Mesh / 802.11s operation.
- RADIUS/enterprise authentication (802.1X); PSK/SAE only.
- Band steering, captive portals or traffic shaping/QoS beyond wmm_enabled.
- Managing host WiFi driver/firmware installation (documented as prerequisite).
- Non-Linux hosts or non-Docker runtimes.
- Persistence of firewall/sysctl changes across host reboots (runtime only;
  host-side persistence is documented in docs/networking.md).

## 5. Future Decisions

Placeholder for additional future decisions. Items under consideration will be
recorded here once decided:

- If `hostapd.conf`/`dnsmasq.conf` generation via heredocs grows unwieldy
  (many more options), consider switching to template files rendered with
  `envsubst` instead of rewriting the entrypoint in another language. Bash
  remains the right tool: the scripts are glue (env interpolation, iptables,
  signal handling) and templates would be a low-cost upgrade.
