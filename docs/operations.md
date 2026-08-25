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

To deauthenticate a specific station, pass its MAC address as a `deauth` subcommand:

```bash
docker exec rpi-hostap clients.sh deauth aa:bb:cc:dd:ee:ff
```

The MAC must be in `aa:bb:cc:dd:ee:ff` format (case-insensitive); invalid addresses are rejected with an error.

See also: the [deep healthcheck](healthcheck.md#deep-healthcheck-optional) uses the same control interface - enabling either option is sufficient for both. Client inspection is also useful to verify that [MAC address filtering](configuration.md#mac-address-filtering-optional) works as expected.

---

_Last updated: 2026-08-24_
