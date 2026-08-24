# Validation

## Dry-Run Validation (`--validate`)

`wlanstart.sh --validate` (aliases: `-t`, `--test`) checks the configuration without touching the system:

```bash
docker run --rm \
  -e INTERFACE=wlan0 -e SSID=myap -e WPA_PASSPHRASE=supersecret -e COUNTRY_CODE=US \
  sdelrio/rpi-hostap:latest --validate
```

It applies the same environment defaults as a normal start, runs every validator (channel/regulatory, passphrase, MAC filter, DHCP range, IPv4 addresses) and, on success, prints the generated `hostapd.conf` and `dnsmasq.conf` to stdout. It performs no system mutations: no interface changes, sysctls, iptables rules or daemons.

On invalid configuration it exits non-zero and lists all validation errors (not just the first). This is covered in CI by the bats suite (`tests/validate_mode.bats`).

Dry-run validation is also the recommended first step when [troubleshooting a container that exits immediately](troubleshooting.md#container-exits-immediately).

See also: [regional channel validation](configuration.md#regional-channel-validation) (checked by the channel/regulatory validator), [MAC filtering](configuration.md#mac-address-filtering-optional) (file presence validated at start) and the [HT/VHT tuning notes](configuration.md#htvht-80211nac-tuning) for values passed through unvalidated.

---

_Last updated: 2026-08-24_
