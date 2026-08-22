FROM alpine:3.24.1

LABEL maintainer="Sergio R. <sdelrio@users.noreply.github.com>"

ENV VERSION=0.31.0

RUN apk add --no-cache \
    bash=5.3.9-r1 \
    hostapd=2.11-r4 \
    iptables=1.8.13-r0 \
    dnsmasq=2.92_p2-r0

COPY wlanstart.sh /bin/wlanstart.sh

# hadolint ignore=DL3025
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD pidof hostapd > /dev/null && pidof dnsmasq > /dev/null || exit 1

ENTRYPOINT [ "/bin/wlanstart.sh" ]
