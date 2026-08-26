FROM alpine:3.24.1

LABEL maintainer="Sergio R. <sdelrio@users.noreply.github.com>"

# Upgrade first so base-image libraries (e.g. libssl/libcrypto) pick up
# security fixes published after the alpine point release was tagged.
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    bash=5.3.9-r1 \
    hostapd=2.11-r4 \
    iptables=1.8.13-r0 \
    dnsmasq=2.92_p2-r0 \
    multirun=1.1.3-r0

# Placed after the apk layer so per-release version bumps do not
# invalidate the package-install cache.
ARG VERSION=dev
ENV WLANSTART_VERSION=${VERSION}

ENV HEALTHCHECK_START_PERIOD=15

COPY wlanstart.sh /bin/wlanstart.sh
COPY healthcheck.sh /bin/healthcheck.sh
COPY clients.sh /bin/clients.sh
COPY lib/ /bin/lib/
RUN chmod +x /bin/healthcheck.sh /bin/clients.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["/bin/healthcheck.sh"]

ENTRYPOINT [ "/bin/wlanstart.sh" ]
