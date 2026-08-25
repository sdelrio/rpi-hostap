# Health Check

> **Audience**: advanced users. This page explains healthcheck internals in depth. If you just see `unhealthy` and want a fix, start with [Troubleshooting](troubleshooting.md#container-exits-immediately) instead.

The container defines a Docker `HEALTHCHECK` that runs `/bin/healthcheck.sh` every 30s (15s start period, 3 retries). The check verifies, in order (relevant variables: [`HEALTHCHECK_START_PERIOD`](../README.md#environment-variables), [`HEALTHCHECK_DEEP`](../README.md#environment-variables)):

1. The container started less than `HEALTHCHECK_START_PERIOD` seconds ago (default 15s); during this grace period the check always passes. The start time is recorded by the entrypoint in `/run/hostap-started` at container boot - `/proc/uptime` is deliberately not used because inside Docker it reflects the *host's* uptime, which would disable the grace period on long-running hosts.
2. The `hostapd` process is running.
3. The `dnsmasq` process is running.
4. The wireless interface (`INTERFACE`) exists and is up.
5. If `AP_ADDR` is set: the address is actually assigned to `INTERFACE` (via `ip -4 addr show`). This catches cases where IP configuration failed after hostapd started.

If any check fails, the container is reported as `unhealthy`.

**Script grace vs Docker start-period**: there are two independent grace mechanisms. `HEALTHCHECK_START_PERIOD` (env var) controls the *script-side* grace window measured from the recorded start time. The Dockerfile's `HEALTHCHECK --start-period=15s` is the Docker-side outer bound during which failing checks do not count towards the `unhealthy` transition. If you raise the env var (e.g. `HEALTHCHECK_START_PERIOD=60`), the script keeps passing for 60s after start regardless of the Docker setting; the Dockerfile start-period only affects when Docker itself starts counting failures.

## Deep Healthcheck (optional)

By default the AP's beaconing status is not verified - hostapd can be alive while the radio failed to start (driver rejection, [DFS](https://en.wikipedia.org/wiki/Dynamic_frequency_selection) CAC wait). Set `HEALTHCHECK_DEEP` to any non-empty value to opt in:

```bash
docker run ... -e HEALTHCHECK_DEEP=1 ...
```

When enabled, `wlanstart.sh` emits `ctrl_interface=/var/run/hostapd` and `ctrl_interface_group=0` into the generated `hostapd.conf`, and after the existing checks `healthcheck.sh` runs `hostapd_cli -p /var/run/hostapd -i "$INTERFACE" status`, requiring `state=ENABLED`. If hostapd reports any other state, the container is reported as `unhealthy`.

**DFS channels**: on radar channels (e.g. 5 GHz DFS), Channel Availability Check (CAC) can take 60s+ before the AP starts beaconing (`state=DFS`). Raise the grace period so the deep check doesn't fail during CAC:

```bash
docker run ... -e HEALTHCHECK_DEEP=1 -e HEALTHCHECK_START_PERIOD=90 ...
```

Note: enabling [`CTRL_INTERFACE`](operations.md#client-inspection-optional) already emits the same config lines, so the two options are compatible - either one suffices for `hostapd_cli` to work.

## Minimum Stations Check (optional)

An AP that beacons and reports `state=ENABLED` may still accept no associations. Set `HEALTHCHECK_MIN_STATIONS=N` to opt in to a station-count check:

```bash
docker run ... -e CTRL_INTERFACE=1 -e HEALTHCHECK_MIN_STATIONS=1 ...
```

When enabled, after all other checks (and only once the grace period has elapsed), `healthcheck.sh` counts associated stations via `hostapd_cli all_sta` - the same count printed by [`clients.sh count`](operations.md#client-inspection-optional) - and fails with a message naming the expected vs actual count if fewer than `N` stations are connected, marking the container `unhealthy`. The check is skipped when the control interface socket directory does not exist.

**DFS/CAC caveat**: the same [DFS](https://en.wikipedia.org/wiki/Dynamic_frequency_selection) caveat as the deep check applies here - on radar channels stations cannot join until beaconing starts after Channel Availability Check (CAC), which can take 60s+. Raise `HEALTHCHECK_START_PERIOD` accordingly or the min-stations check will fail during CAC even on a healthy AP.

See also: [regional channel validation](configuration.md#regional-channel-validation) for which 5 GHz channels are [DFS](https://en.wikipedia.org/wiki/Dynamic_frequency_selection) and trigger CAC.

---

_Last updated: 2026-08-25_
