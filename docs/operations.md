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

See also: the [deep healthcheck](healthcheck.md#deep-healthcheck-optional) uses the same control interface — enabling either option is sufficient for both.
