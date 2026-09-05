---
title: "Networking"
---

## Subnet Mask

The subnet prefix defaults to `/24` (netmask `255.255.255.0`). To use a different subnet size, set the netmask field of `DHCP_RANGE` explicitly; the prefix is derived from it and applied everywhere (AP interface address, NAT rules):

```bash
docker run ... -e SUBNET=192.168.254.16 -e AP_ADDR=192.168.254.17 \
    -e DHCP_RANGE="192.168.254.20,192.168.254.30,255.255.255.240,12h" ...
```

Notes:

- The mask must be contiguous (e.g. `255.255.255.240` = `/28`).
- `SUBNET` must be the network address for that mask (host bits zero); e.g. for a `/28`, the last octet must be a multiple of 16.
- When `DHCP_RANGE` is unset, the default range uses a `/24` layout, so `SUBNET` must end in `.0`.

## Interface Address Handling

At startup the container flushes existing addresses on `INTERFACE` and assigns `AP_ADDR/<prefix>` to it. On shutdown, only the address this container configured (`AP_ADDR`) is removed - a blanket `ip addr flush` is deliberately avoided so that unrelated host addresses are preserved. This matters with `--net host`, where the interface is shared with the host (e.g. a manually added `192.168.254.1/24` survives container teardown).

## NAT / IP Forwarding

The container enables IP forwarding at runtime. For persistence across host reboots:

```bash
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf
sudo sysctl -p
```

## IPv6 Support (optional)

IPv6 is **off by default**; behavior is unchanged unless you set `IPV6=1`. When enabled:

- `net.ipv6.conf.all.forwarding=1` is set at runtime (IPv6 forwarding).
- dnsmasq advertises SLAAC/RA with stateless DHCPv6 on the AP interface:
  `dhcp-range=::,constructor:<INTERFACE>,ra-names,stateless`
- `ip6tables` FORWARD rules mirror the IPv4 handling (established/related in, new out). There is no IPv6 NAT - clients get addresses from the upstream network's prefix via RA, or link-local/ULA otherwise.

```bash
docker run ... -e IPV6=1 ...
```

### Caveats

- Client IPv6 connectivity depends on the upstream network advertising an IPv6 prefix (Router Advertisements on the outgoing interface). Without an upstream prefix, clients will only obtain link-local addresses.
- The container sets forwarding at runtime via `/proc/sys`; for host persistence across reboots see the sysctl commands above.
- Some ISPs/hosters filter or rate-limit IPv6; test with `ping6` / `traceroute -6` from a client.

See also: [IPv6 troubleshooting](troubleshooting.md#ipv6-no-connectivity-or-only-link-local-addresses) for diagnosing missing upstream prefixes and RA issues.

## Outgoing Interfaces

By default, NAT is applied to all outgoing interfaces. To restrict NAT to specific interfaces, set `OUTGOINGS` to a comma-separated list when running the container:

```bash
docker run ... -e OUTGOINGS=eth0 ...
```

For multiple interfaces:

```bash
docker run ... -e OUTGOINGS=eth0,wwan0 ...
```

---

_Last updated: 2026-08-25_
