# Operations

Day-to-day operation and diagnostics of a running AP.

## Client Inspection (optional)

By default the hostapd control interface is not enabled, to keep the generated config minimal. Set `CTRL_INTERFACE` to any non-empty value to opt in:

```bash
docker run ... -e CTRL_INTERFACE=1 ...
```

This emits `ctrl_interface=/var/run/hostapd` and `ctrl_interface_group=0` into `hostapd.conf`. Once enabled, list currently associated stations from inside the container:

```bash
docker exec rpi-hostap clients.sh
```

Output includes MAC address, signal, connected time and tx/rx rates per station (as reported by `hostapd_cli all_sta`). The control interface directory can be overridden with `CTRL_IFACE_DIR` (default `/var/run/hostapd`).

For machine-readable output, pass `--json` to get a JSON array of station objects with `mac`, `aid`, `signal` and `connected_time` fields:

```bash
docker exec rpi-hostap clients.sh --json
```

Example output:

```json
[{"mac":"aa:bb:cc:dd:ee:ff","aid":"1","signal":"-45","connected_time":"120"}]
```

For a quick machine-friendly count of associated stations, use the `count` subcommand:

```bash
docker exec rpi-hostap clients.sh count
```

It prints a single integer (the number of station MAC blocks in `hostapd_cli all_sta` output), suitable for scripting and monitoring.

### DHCP leases

To inspect current dnsmasq DHCP leases, use the `leases` subcommand:

```bash
docker exec rpi-hostap clients.sh leases
```

It prints the raw lease lines in dnsmasq format (`expiry_epoch mac ip hostname clientid`). The lease file path defaults to `/tmp/dnsmasq.leases` (emitted as `dhcp-leasefile` in the generated config) and can be overridden with `DHCP_LEASE_FILE`. If the lease file is absent, an error is reported.

For machine-readable output, pass `--json`:

```bash
docker exec rpi-hostap clients.sh leases --json
```

Example output:

```json
[{"mac":"aa:bb:cc:dd:ee:ff","ip":"192.168.254.100","hostname":"laptop","expires":"1756200000"}]
```

To deauthenticate a specific station, pass its MAC address as a `deauth` subcommand:

```bash
docker exec rpi-hostap clients.sh deauth aa:bb:cc:dd:ee:ff
```

The MAC must be in `aa:bb:cc:dd:ee:ff` format (case-insensitive); invalid addresses are rejected with an error.

See also: the [deep healthcheck](healthcheck.md#deep-healthcheck-optional) uses the same control interface - enabling either option is sufficient for both. Client inspection is also useful to verify that [MAC address filtering](configuration.md#mac-address-filtering-optional) works as expected.

---

_Last updated: 2026-08-25_
