# rpi-hostap Documentation

Lightweight Docker container that turns a Raspberry Pi into a wireless Access Point with DHCP server. See the main [README](../README.md) for overview, prerequisites and quick start.

## Contents

| Document | Description |
|----------|-------------|
| [Configuration](configuration.md) | [HT/VHT tuning](configuration.md#htvht-80211nac-tuning), [MAC filtering](configuration.md#mac-address-filtering-optional), [WPA3/SAE](configuration.md#wpa3-sae), [regional channels](configuration.md#regional-channel-validation), [dry-run validation](configuration.md#dry-run-validation---validate), [client inspection](configuration.md#client-inspection-optional) |
| [Networking](networking.md) | NAT / IP forwarding, IPv6 support, outgoing interfaces |
| [Troubleshooting](troubleshooting.md) | Common errors: kernel driver conflicts, containers exiting immediately |
| [Health Check](healthcheck.md) | Container healthcheck internals, grace periods, deep healthcheck |

## Quick reference

- Environment variables: [README table](../README.md#environment-variables)
- Test a configuration without touching the system: [`wlanstart.sh --validate`](configuration.md#dry-run-validation---validate)
- List connected clients: [`clients.sh` / `CTRL_INTERFACE`](configuration.md#client-inspection-optional)
