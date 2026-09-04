# rpi-hostap Documentation

Lightweight Docker container that turns a Raspberry Pi into a wireless Access Point with DHCP server. See the main [README](../README.md) for overview, prerequisites, quick start and the environment variable reference.

## How do I...

| Goal | Variable(s) | Docs |
|------|-------------|------|
| Change the network name or password | `SSID`, `WPA_PASSPHRASE` | [README environment variables](../README.md#environment-variables) |
| Hide my SSID (don't broadcast the network name) | `HIDE_SSID=1` | [README](../README.md#environment-variables) |
| Only let specific devices (my laptop) connect | `MAC_FILTER=1`, `MAC_ACL_FILE` | [MAC address filtering](configuration.md#mac-address-filtering-optional) |
| Block specific devices | `MAC_FILTER=2`, `MAC_ACL_FILE` | [MAC address filtering](configuration.md#mac-address-filtering-optional) |
| Limit how many clients can connect | `MAX_STATIONS` | [README](../README.md#environment-variables) |
| Stop clients from seeing each other | `AP_ISOLATION=1` | [README](../README.md#environment-variables) |
| Use WPA3 (or WPA2/WPA3 transition mode) | `WPA_VERSION=3` / `mixed` | [WPA3 (SAE)](configuration.md#wpa3-sae), [verifying client SAE support](configuration.md#verifying-client-sae-support) |
| Get faster WiFi (802.11n/ac, 5 GHz) | `HW_MODE=a`, `CHANNEL`, `HT_ENABLED`, `HT_CAPAB`, `VHT_ENABLED`, `VHT_CAPAB` | [HT/VHT tuning](configuration.md#htvht-80211nac-tuning) |
| Use a different channel / country | `CHANNEL`, `COUNTRY_CODE` | [Regional channel validation](configuration.md#regional-channel-validation) |
| Change the AP's IP address or DHCP range | `AP_ADDR`, `SUBNET`, `DHCP_RANGE`, `DHCP_LEASE` | [README](../README.md#environment-variables) |
| Change DNS servers given to clients | `PRI_DNS`, `SEC_DNS` | [README](../README.md#environment-variables) |
| Enable IPv6 for clients | `IPV6=1` | [IPv6 support](networking.md#ipv6-support-optional) |
| Restrict NAT to specific outgoing interfaces | `OUTGOINGS` | [Outgoing interfaces](networking.md#outgoing-interfaces) |
| Make IP forwarding persist across reboots | host sysctl config | [NAT / IP forwarding](networking.md#nat--ip-forwarding) |
| List connected clients | `CTRL_INTERFACE=1` + `clients.sh` | [Client inspection](operations.md#client-inspection-optional) |
| Count connected clients | `CTRL_INTERFACE=1` + `clients.sh count` | [Client inspection](operations.md#client-inspection-optional) |
| Show DHCP leases | `CTRL_INTERFACE=1` + `clients.sh leases` | [DHCP leases](operations.md#dhcp-leases) |
| Disconnect a client | `CTRL_INTERFACE=1` + `clients.sh deauth <mac-address>` | [Client inspection](operations.md#client-inspection-optional) |
| Verify the AP is actually beaconing | `HEALTHCHECK_DEEP=1` | [Deep healthcheck](healthcheck.md#deep-healthcheck-optional) |
| Give a DFS channel time to start (CAC wait) | `HEALTHCHECK_START_PERIOD` | [Deep healthcheck: DFS channels](healthcheck.md#deep-healthcheck-optional) |
| Test my configuration without touching the system | `--validate` flag | [Dry-run validation](validation.md#dry-run-validation---validate) |
| Fix "Could not connect to kernel driver" | - | [Troubleshooting](troubleshooting.md#could-not-connect-to-kernel-driver) |
| Fix a container that exits immediately | - | [Troubleshooting](troubleshooting.md#container-exits-immediately) |
| Diagnose missing IPv6 connectivity on clients | `IPV6` | [IPv6 troubleshooting](troubleshooting.md#ipv6-no-connectivity-or-only-link-local-addresses) |
| Understand why the container is `unhealthy` | `HEALTHCHECK_START_PERIOD`, `HEALTHCHECK_DEEP` | [Health Check](healthcheck.md) |
| Preserve crash logs for debugging | `FAILURE_LOG_DIR`, `FAILURE_LOG_KEEP`, `FAILURE_LOG_PATH` | [Preserved failure logs](troubleshooting.md#preserved-failure-logs) |
| Audit a running system against its config | `--check` flag | [Runtime state audit](validation.md#runtime-state-audit---check) |
| Require minimum connected clients | `HEALTHCHECK_MIN_STATIONS` | [Minimum station count](healthcheck.md#minimum-stations-check-optional) |
| Auto-select WiFi channel | `CHANNEL=acs` | [ACS](configuration.md#automatic-channel-selection-acs) |
| Use a non-standard WiFi driver | `DRIVER` | [Driver override](configuration.md#driver-override) |

## Contents

| Document | Description |
|----------|-------------|
| [SPEC](../SPEC.md) | Project requirements: purpose, functional and non-functional requirements, non-goals |
| [Configuration](configuration.md) | [HT/VHT tuning](configuration.md#htvht-80211nac-tuning), [MAC filtering](configuration.md#mac-address-filtering-optional), [WPA3/SAE](configuration.md#wpa3-sae), [regional channels](configuration.md#regional-channel-validation) |
| [Networking](networking.md) | NAT / IP forwarding, IPv6 support, outgoing interfaces |
| [Validation](validation.md) | Dry-run config checks with [`--validate`](validation.md#dry-run-validation---validate) |
| [Operations](operations.md) | [Client inspection](operations.md#client-inspection-optional), runtime diagnostics |
| [Troubleshooting](troubleshooting.md) | Common errors: kernel driver conflicts, containers exiting immediately |
| [Health Check](healthcheck.md) | Container healthcheck internals, grace periods, deep healthcheck |
| [CI](CI.md) | E2E Test workflow, hwsim module cache and branch scoping |

## Quick reference

| Task | Where |
|------|-------|
| List all environment variables | [README table](../README.md#environment-variables) |
| Test a configuration without touching the system | [`wlanstart.sh --validate`](validation.md#dry-run-validation---validate) |
| Complete `docker run` example with all option groups | [README](../README.md#full-featured-example) |
| List connected clients | [`clients.sh`](operations.md#client-inspection-optional) |

---

_Last updated: 2026-08-24_
