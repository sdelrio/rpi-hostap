# Configuration

> **Audience**: intermediate users. Assumes you have a running AP (see the README [quick start](../README.md)) and are comfortable reading `docker logs` and shell command output. Beginners: each section explains what to run and what output to expect before changing anything.

The full list of environment variables lives in the main [README](../README.md#environment-variables). This page covers detailed radio and security topics with examples. For validation tooling see [validation.md](validation.md); for running diagnostics see [operations.md](operations.md).

## HT/VHT (802.11n/ac) Tuning

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

### Notes

- `HT_ENABLED=1` emits `ieee80211n=1`; `HT_CAPAB` sets the optional `ht_capab=` line.
- `VHT_ENABLED=1` emits `ieee80211ac=1` and requires 5 GHz operation (`HW_MODE=a`); `VHT_CAPAB` sets the optional `vht_capab=` line.
- Capabilities depend on what your WiFi adapter supports - check `iw list` output (`HT capabilities` / `VHT capabilities`) before enabling. See [Verifying HT/VHT support](#verifying-htvht-support) below for what to look for.
- Common `ht_capab` flags: `[HT40+]`/`[HT40-]` (40 MHz channels), `[SHORT-GI-20]`, `[SHORT-GI-40]`. Common `vht_capab` flags: `[SHORT-GI-80]`, `[MAX-MPDU-3895]`, `[SU-BEAMFORMER]`.
- `HT_CAPAB`/`VHT_CAPAB` values are passed through to hostapd unvalidated; invalid strings surface as hostapd config errors in `docker logs`.

See also: [regional channel validation](#regional-channel-validation) - channel choice interacts with your country's regulatory limits.

### Verifying HT/VHT support

Run this on the Raspberry Pi host (the container does not include `iw`):

```bash
iw list
```

Look for two blocks in the output: `HT capabilities` (2.4 GHz and 5 GHz) and `VHT capabilities` (5 GHz only). Example from a 5 GHz-capable adapter:

```
	Band 2:
		Capabilities: 0x11ce
			RX LDPC			yes
			Support for channel width:
				* 40 MHz		(HT40)	yes
			...
		HT capabilities:
			Capabilities: 0x9ef
				RX HT20 SGI		yes
				RX HT40 SGI		yes
				TX STBC			yes (BEAMFORM0 streams)
		VHT capabilities:
			VHT Capabilities (as reported by the driver):
				RX LDPC			yes
				Supported Channel Width:
					160 MHz		no
				Short GI for 80 MHz	yes
```

Interpretation:

- If the band has no `HT capabilities` block at all, do not set `HT_ENABLED=1`.
- `RX HT40 SGI yes` means `[HT40+]/[HT40-]` and `[SHORT-GI-40]` are safe to enable; if it is missing, drop those flags.
- `Short GI for 80 MHz yes` means `[SHORT-GI-80]` is supported. If there is no `VHT capabilities` block, the adapter cannot do 802.11ac and you must not set `VHT_ENABLED=1`.

If hostapd rejects your capability string, it shows up as a config error in `docker logs rpi-hostap` on start.

## HE (802.11ax) Tuning

By default the AP runs without HE (802.11ax/Wi-Fi 6). To enable it:

```bash
docker run ... \
  -e HW_MODE=a -e CHANNEL=36 \
  -e HE_ENABLED=1 \
  -e HE_CAPAB="[HE80:[0x11ff:0xf]]" \
   ...
```

### Notes

- `HE_ENABLED=1` emits `ieee80211ax=1` and requires 5 GHz operation (`HW_MODE=a`), the same band rule as VHT; `HE_CAPAB` sets the optional `he_capab=` line.
- Capabilities depend on what your WiFi adapter supports - check `iw list` output for an `HE capabilities` block before enabling. If there is no such block, the adapter cannot do 802.11ax and you must not set `HE_ENABLED=1`.
- `HE_CAPAB` is optional - `ieee80211ax=1` alone works with driver defaults. When set, `he_capab` uses band-specific syntax, e.g. `[HE80:[0x11ff:0xf]]` for 5 GHz (MAC capabilities in hex). See the hostapd `hostapd.conf` documentation for the full format.
- `HE_CAPAB` values are passed through to hostapd unvalidated; invalid strings surface as hostapd config errors in `docker logs`.

## Transmit Power (optional)

Regulatory-constrained deployments (labs, embedded products) may need to cap the AP's EIRP. Set `TX_POWER` to a fixed transmit power in dBm, or `auto` to restore driver/regulatory automatic power control:

```bash
docker run ... \
  -e COUNTRY_CODE=ES \
  -e TX_POWER=10 \
  ...
```

- Unset (default): the driver default power is left untouched.
- `TX_POWER=20`: applied at startup as `iw dev <iface> set txpower fixed 20`.
- `TX_POWER=auto`: applied as `iw dev <iface> set txpower auto`.

### Notes

- The cap must respect your `COUNTRY_CODE` regulatory limits - `iw` rejects powers above the allowed EIRP for the configured domain. Setting a country code alone does not cap power; `TX_POWER` is the explicit limit.
- Failure to apply is **fatal**: if you explicitly ask for a power cap and it cannot be set, the container exits with a clear error rather than silently transmitting at full power. Check the value against `iw reg` output on the host if startup fails.

## MAC Address Filtering (optional)

MAC filtering is **off by default**; behavior is unchanged unless you set `MAC_FILTER`. When enabled:

- `MAC_FILTER=1` (allowlist): only MACs listed in the file can associate (`macaddr_acl=1` + `accept_mac_file=`).
- `MAC_FILTER=2` (denylist): listed MACs are rejected (`macaddr_acl=0` + `deny_mac_file=`).

**hostapd `macaddr_acl` semantics**: `macaddr_acl=0` means accept all clients *unless* listed in `deny_mac_file` (denylist mode); `macaddr_acl=1` means deny all clients *unless* listed in `accept_mac_file` (allowlist mode). The two directives are mutually exclusive in hostapd - only one file type is effective per mode.
- Startup fails with an error if the filter is enabled without `MAC_ACL_FILE`, and warns if the file is missing or unreadable.
- Note that MAC filtering is a weak control on its own (MACs can be spoofed); combine it with [WPA3/SAE](#wpa3-sae).

```bash
docker run ... -e MAC_FILTER=1 -v /path/to/hostapd.accept:/etc/hostapd.accept:ro ...
```

### File Format

One MAC per line:

```
aa:bb:cc:dd:ee:ff
11:22:33:44:55:66
```

See also: [client inspection](operations.md#client-inspection-optional) - use `clients.sh` to list associated stations and verify the filter allows/blocks the expected MACs.

## Secret-File Inputs (optional)

`SSID` and `WPA_PASSPHRASE` are normally passed with `docker run -e`, which makes them visible via `docker inspect` and shell history. Both support the `_FILE` convention (as used by Docker secrets, e.g. `docker secret` / Swarm / `docker compose` `secrets:`):

- `SSID_FILE`: path to a file whose **first line** holds the SSID
- `WPA_PASSPHRASE_FILE`: path to a file whose **first line** holds the passphrase

```bash
docker run -d --name hostap \
  --privileged --net host \
  -v /run/secrets:/run/secrets:ro \
  -e INTERFACE=wlan0 \
  -e SSID_FILE=/run/secrets/ssid \
  -e WPA_PASSPHRASE_FILE=/run/secrets/wpa_passphrase \
  sdelrio/rpi-hostap
```

Behavior:

- Only the first line of the file is used; a trailing newline is stripped.
- Values loaded from files go through the same validation as direct values (`validation_check_ssid`, `passphrase_validate`).
- If both `VAR` and `VAR_FILE` are set, the `_FILE` value wins and a warning is printed to stderr.
- Startup fails with `[Error] <VAR>_FILE '...' is not readable` if the file is missing or unreadable.

## WPA3 (SAE)

### WPA3-Only (`WPA_VERSION=3`)

Setting `WPA_VERSION=3` enables WPA3-SAE authentication. Note:

- Client devices must support SAE (wpa_supplicant 2.7+, iOS 13+/macOS 10.15+, Android 10+).
- Older clients that only support WPA2 will not be able to connect.

#### Verifying client SAE support

Before switching a live AP to WPA3-only, verify each client device:

- **Linux client**: check the wpa_supplicant version (`wpa_supplicant -v`; needs 2.7+) and that `sae` appears in its build config: `wpa_supplicant -v` output includes compile-time `CONFIG_SAE=y` on recent distro builds. Then try connecting and confirm with `wpa_cli status` that it reports `key_mgmt=SAE`.
- **macOS**: System Information > Network > Wi-Fi, or hold Option while clicking the Wi-Fi menu icon - "PHY Mode" showing `802.11ax` or firmware from macOS 10.15+ generally means WPA3 support. Definitive test: connect to this AP in [transition mode](#transition-mode-wpa_versionmixed) first, then check `System Settings > Wi-Fi > Details`, which shows `Security: WPA3 Personal` for SAE connections.
- **Windows**: `netsh wlan show drivers` - look for `WPA3 Personal` (or `SAE`) under authentication/cipher support. If absent, the client only does WPA2.
- **Android**: Settings > Wi-Fi network details after connecting shows `Security: WPA3` on supported devices; otherwise fall back to transition mode.

If any required client lacks SAE support, use `WPA_VERSION=mixed` instead.

### Transition Mode (`WPA_VERSION=mixed`)

Setting `WPA_VERSION=mixed` enables WPA2/WPA3 transition mode: WPA3-SAE capable devices use SAE, while legacy WPA2 clients can still connect with WPA2-PSK. Note that transition mode is considered less secure than WPA3-only.

## PMF (802.11w)

Protected Management Frames (PMF, IEEE 802.11w) encrypt deauthentication and other management frames, protecting clients from spoofed deauth attacks. It is configured in hostapd.conf via `ieee80211w`.

By default PMF is derived from `WPA_VERSION`:

| WPA_VERSION | Emitted | Why |
|-------------|-----------------|-----|
| `2` | nothing | WPA2-only keeps maximum legacy compatibility |
| `3` | `ieee80211w=2` | WPA3-SAE mandates PMF |
| `mixed` | `ieee80211w=1` | transition mode makes PMF optional so legacy clients can join |

Set `PMF` explicitly to override the derived default:

| Value | Emitted | Meaning |
|-------|---------|---------|
| `0` | `ieee80211w=0` | disabled |
| `1` | `ieee80211w=1` | optional |
| `2` | `ieee80211w=2` | required |

Notes:

- Any other value fails startup with `[Error] Invalid PMF '...'. Must be 0 (disabled), 1 (optional) or 2 (required).`
- `PMF=0` combined with `WPA_VERSION=3` is rejected: WPA3-SAE requires Protected Management Frames.
- Enabling `PMF=2` on a WPA2-only network requires client support for 802.11w; older devices will fail to associate.

```bash
docker run -d --name hostap \
  --privileged --net host \
  -e INTERFACE=wlan0 -e SSID=myap -e WPA_PASSPHRASE=changeme \
  -e WPA_VERSION=mixed -e PMF=2 \
  sdelrio/rpi-hostap
```

## Regional Channel Validation

When `COUNTRY_CODE` is set, channels are validated against regional limits.

### Automatic Channel Selection (ACS)

Setting `CHANNEL=acs` enables automatic channel selection. The WiFi driver scans available channels and selects the best one based on current interference and signal conditions.

```bash
docker run ... \
  -e CHANNEL=acs \
  ...
```

#### How it works

When `CHANNEL=acs` is set, the driver performs a channel scan at startup and selects the channel with the least interference. This is useful in dynamic environments where the optimal channel may change over time.

#### Driver support

Not all WiFi drivers support ACS. Check your driver's documentation or run `iw list` to see if ACS is supported. If ACS is not supported, the container will fail with an error.

#### DFS/CAC caveat

ACS may select a DFS (Dynamic Frequency Selection) radar channel. When this happens:

- The AP must perform Channel Availability Check (CAC) before transmitting, which can take 60+ seconds
- Clients cannot connect until CAC completes
- The container may report as `unhealthy` during this period

To accommodate DFS channels, set `HEALTHCHECK_START_PERIOD` to at least 90 seconds:

```bash
docker run ... \
  -e CHANNEL=acs \
  -e HEALTHCHECK_START_PERIOD=90 \
  ...
```

#### Startup delay

Startup may be delayed while the driver scans channels. The delay depends on the number of channels scanned and driver implementation. Plan for 10-30 seconds of additional startup time when using ACS.

### 2.4 GHz Channels

For 2.4 GHz (`hw_mode=g` or `b`):

| Region | Countries | Allowed Channels (2.4 GHz) |
|--------|-----------|---------------------------|
| North America | US, CA, MX | 1–11 |
| Europe (ETSI) | EU, UK, ES, ... (default) | 1–13 |
| Japan | JP | 1–14 |

Unknown countries fall back to the ETSI limit (1–13). A warning is emitted if `COUNTRY_CODE` is not set.

### 5 GHz Channels

For 5 GHz (`hw_mode=a`), channels are validated against the allowed 5 GHz set:

- **Non-DFS channels** (always allowed): 36, 40, 44, 48, 149, 153, 157, 161, 165
- **[DFS](https://en.wikipedia.org/wiki/Dynamic_frequency_selection) channels** (allowed with a radar detection/CAC warning): 52, 56, 60, 64, 100–144 (in steps of 4)
- Any other channel is rejected with a clear error.

See also: [DFS CAC wait times](healthcheck.md#deep-healthcheck-optional) affect the healthcheck grace period on radar channels, and [dry-run validation](validation.md#dry-run-validation---validate) checks your chosen channel against these limits without touching the system.

## Driver Override

By default, hostapd uses the `nl80211` driver interface, which works with most modern WiFi adapters. Some adapters (particularly older Realtek chipsets) require a different driver.

### When to use `DRIVER`

Use the `DRIVER` environment variable when:

- Your adapter requires a non-standard hostapd driver (e.g., `rtl871xdrv` for some Realtek adapters)
- You see errors like "Could not connect to kernel driver" or "nl80211 driver initialization failed"

### Checking your adapter's driver

Run `iw list` on the host to see supported interfaces. Look for the `Supported interface modes` section. If your adapter supports `AP` mode under `nl80211`, you don't need a driver override.

If you're unsure, check your adapter's documentation or search for your specific chipset model with "hostapd driver" to see what others have used.

### Example

```bash
docker run ... \
  -e DRIVER=rtl871xdrv \
  ...
```

### Default behavior

When `DRIVER` is unset, hostapd uses the default `nl80211` driver. This is the recommended configuration for most users.

### Error handling

If you set an invalid driver name, hostapd will fail with a clear error message in `docker logs`. The container will exit immediately rather than running in a broken state.

## Extra hostapd Options

`HOSTAPD_EXTRA_OPTS` allows you to inject custom hostapd.conf lines that are appended verbatim after all generated configuration. This is useful for power users who need to set options not exposed by environment variables.

### Syntax

The value is a newline-separated list of `key=value` pairs in raw hostapd.conf format:

```bash
docker run ... \
  -e HOSTAPD_EXTRA_OPTS="auth_algs=3\nbeacon_int=100" \
  ...
```

### Common use cases

| Option | Description | Example |
|--------|-------------|---------|
| `beacon_int` | Beacon interval in TU (1 TU = 1024 µs) | `beacon_int=100` |
| `auth_algs` | Authentication algorithms (1=Open, 2=Shared, 3=Both) | `auth_algs=3` |
| `wmm_uapsd` | Enable WMM U-APSD (unscheduled power save) | `wmm_uapsd=1` |
| `dtim_period` | DTIM period (beacons between DTIMs) | `dtim_period=2` |
| `rts_threshold` | RTS/CTS threshold in bytes | `rts_threshold=2347` |

### Important notes

- Values are **unvalidated** - they are passed directly to hostapd without checking
- Invalid values will cause hostapd to fail at startup with errors in `docker logs`
- Lines are appended after all generated config, so they can override earlier directives
- Use this only when you understand the hostapd.conf format and the specific option

---

_Last updated: 2026-08-24_
