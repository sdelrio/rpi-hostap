FROM alpine:3.24.1

LABEL maintainer="Sergio R. <sdelrio@users.noreply.github.com>"

RUN apk add --no-cache \
    bash=5.3.9-r1 \
    hostapd=2.11-r4 \
    iptables=1.8.13-r0 \
    dnsmasq=2.92_p2-r0

ENV HEALTHCHECK_START_PERIOD=15

COPY wlanstart.sh /bin/wlanstart.sh
COPY healthcheck.sh /bin/healthcheck.sh
RUN chmod +x /bin/healthcheck.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["/bin/healthcheck.sh"]

ENTRYPOINT [ "/bin/wlanstart.sh" ]
