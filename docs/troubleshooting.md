# Troubleshooting

## "Could not connect to kernel driver"

`wpa_supplicant` is using the interface. Stop it on the host (see also [Prerequisites](../README.md#disable-wpa_supplicant)):

```bash
sudo systemctl stop wpa_supplicant
```

## Container exits immediately

Check logs:

```bash
docker logs rpi-hostap
```

Ensure the WiFi interface is up and not in use by another process.

To test your configuration without touching the system, use [dry-run validation (`--validate`)](validation.md#dry-run-validation---validate).

If the container runs but is reported as `unhealthy`, see [Health Check](healthcheck.md).

---

_Last updated: 2026-08-24_
