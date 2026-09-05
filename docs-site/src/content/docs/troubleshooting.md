---
title: "Troubleshooting"
---

> **Audience**: beginners welcome. Each section is self-contained and assumes no prior knowledge beyond a running container.

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

## Preserved failure logs

When the container exits because a daemon failed to start, the full tagged
daemon output is preserved so you can inspect it after exit. Each crash
writes a timestamped copy to `FAILURE_LOG_DIR` (default `/var/log/hostap-failures/`),
e.g. `/var/log/hostap-failures/hostap-failure-1756100000.log`, and only the
newest `FAILURE_LOG_KEEP` copies (default 5) are retained - older ones are
pruned automatically. The final error message names the exact file that was
saved.

Tune via environment variables:

| Variable           | Default                     | Purpose                                  |
|--------------------|-----------------------------|------------------------------------------|
| `FAILURE_LOG_DIR`  | `/var/log/hostap-failures`  | Directory for timestamped failure logs   |
| `FAILURE_LOG_KEEP` | `5`                         | Number of failure logs to retain         |
| `FAILURE_LOG_PATH` | unset                       | Legacy fixed path (no rotation) if set   |

## IPv6: no connectivity or only link-local addresses

If clients get no global IPv6 address, check that:

- `IPV6=1` is set on the container (IPv6 is off by default) - see [IPv6 support](networking.md#ipv6-support-optional).
- The upstream network advertises an IPv6 prefix via Router Advertisements; without one clients only obtain link-local addresses.
- Host IPv6 forwarding is persistent (`net.ipv6.conf.all.forwarding=1` in `/etc/sysctl.conf`) - see [NAT / IP forwarding](networking.md#nat--ip-forwarding).

Test from a client with `ping6` / `traceroute -6`. See also the [IPv6 caveats](networking.md#caveats).

---

_Last updated: 2026-08-24_
