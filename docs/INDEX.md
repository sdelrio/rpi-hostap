# rpi-hostap Documentation

Lightweight Docker container that turns a Raspberry Pi into a wireless Access Point with DHCP server. See the main [README](../README.md) for overview, prerequisites, quick start and the environment variable reference.

## Contents

| Document | Description |
|----------|-------------|
| [Configuration](configuration.md) | [HT/VHT tuning](configuration.md#htvht-80211nac-tuning), [MAC filtering](configuration.md#mac-address-filtering-optional), [WPA3/SAE](configuration.md#wpa3-sae), [regional channels](configuration.md#regional-channel-validation) |
| [Networking](networking.md) | NAT / IP forwarding, IPv6 support, outgoing interfaces |
| [Validation](validation.md) | Dry-run config checks with [`--validate`](validation.md#dry-run-validation---validate) |
| [Operations](operations.md) | [Client inspection](operations.md#client-inspection-optional), runtime diagnostics |
| [Troubleshooting](troubleshooting.md) | Common errors: kernel driver conflicts, containers exiting immediately |
| [Health Check](healthcheck.md) | Container healthcheck internals, grace periods, deep healthcheck |

## Quick reference

| Task | Where |
|------|-------|
| List all environment variables | [README table](../README.md#environment-variables) |
| Test a configuration without touching the system | [`wlanstart.sh --validate`](validation.md#dry-run-validation---validate) |
| Complete `docker run` example with all option groups | [README](../README.md#full-featured-example) |
| List connected clients | [`clients.sh`](operations.md#client-inspection-optional) |

---

_Last updated: 2026-08-24_
