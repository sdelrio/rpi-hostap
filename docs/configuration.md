# Configuration

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

Notes:

- `HT_ENABLED=1` emits `ieee80211n=1`; `HT_CAPAB` sets the optional `ht_capab=` line.
- `VHT_ENABLED=1` emits `ieee80211ac=1` and requires 5 GHz operation (`HW_MODE=a`); `VHT_CAPAB` sets the optional `vht_capab=` line.
- Capabilities depend on what your WiFi adapter supports - check `iw list` output (`HT capabilities` / `VHT capabilities`) before enabling.
- Common `ht_capab` flags: `[HT40+]`/`[HT40-]` (40 MHz channels), `[SHORT-GI-20]`, `[SHORT-GI-40]`. Common `vht_capab` flags: `[SHORT-GI-80]`, `[MAX-MPDU-3895]`, `[SU-BEAMFORMER]`.
- `HT_CAPAB`/`VHT_CAPAB` values are passed through to hostapd unvalidated; invalid strings surface as hostapd config errors in `docker logs`.

See also: [regional channel validation](#regional-channel-validation) - channel choice interacts with your country's regulatory limits.

## MAC Address Filtering (optional)

MAC filtering is **off by default**; behavior is unchanged unless you set `MAC_FILTER`. When enabled:

- `MAC_FILTER=1` (allowlist): only MACs listed in the file can associate (`macaddr_acl=1` + `accept_mac_file=`).
- `MAC_FILTER=2` (denylist): listed MACs are rejected (`macaddr_acl=1` + `deny_mac_file=`).
- Startup fails with an error if the filter is enabled without `MAC_ACL_FILE`, and warns if the file is missing or unreadable.
- Note that MAC filtering is a weak control on its own (MACs can be spoofed); combine it with [WPA3/SAE](#wpa3-sae).

```bash
docker run ... -e MAC_FILTER=1 -v /path/to/hostapd.accept:/etc/hostapd.accept:ro ...
```

File format (one MAC per line):

```
aa:bb:cc:dd:ee:ff
11:22:33:44:55:66
```

## WPA3 (SAE)

Setting `WPA_VERSION=3` enables WPA3-SAE authentication. Note:
- Client devices must support SAE (wpa_supplicant 2.7+, iOS 13+/macOS 10.15+, Android 10+).
- Older clients that only support WPA2 will not be able to connect.

Setting `WPA_VERSION=mixed` enables WPA2/WPA3 transition mode: WPA3-SAE capable devices use SAE, while legacy WPA2 clients can still connect with WPA2-PSK. Note that transition mode is considered less secure than WPA3-only.

## Regional Channel Validation

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

See also: [DFS CAC wait times](healthcheck.md#deep-healthcheck-optional) affect the healthcheck grace period on radar channels.
