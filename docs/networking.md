# Networking

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
- `ip6tables` FORWARD rules mirror the IPv4 handling (established/related in, new out). There is no IPv6 NAT — clients get addresses from the upstream network's prefix via RA, or link-local/ULA otherwise.

```bash
docker run ... -e IPV6=1 ...
```

Caveats:

- Client IPv6 connectivity depends on the upstream network advertising an IPv6 prefix (Router Advertisements on the outgoing interface). Without an upstream prefix, clients will only obtain link-local addresses.
- The container sets forwarding at runtime via `/proc/sys`; for host persistence across reboots see the sysctl commands above.
- Some ISPs/hosters filter or rate-limit IPv6; test with `ping6` / `traceroute -6` from a client.

## Outgoing Interfaces

By default, NAT is applied to all outgoing interfaces. To restrict to specific interfaces (e.g., `eth0`):

```bash
-e OUTGOINGS=eth0
```

For multiple interfaces:

```bash
-e OUTGOINGS=eth0,wwan0
```
