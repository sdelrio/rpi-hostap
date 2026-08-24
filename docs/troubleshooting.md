# Troubleshooting

## "Could not connect to kernel driver"

`wpa_supplicant` is using the interface. Stop it on the host:

```bash
sudo systemctl stop wpa_supplicant
```

## Container exits immediately

Check logs:

```bash
docker logs rpi-hostap
```

Ensure the WiFi interface is up and not in use by another process.
