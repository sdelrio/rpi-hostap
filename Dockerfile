FROM jonaskello/rpi-alpine-scratch-qemu

MAINTAINER Sergio R. <sdelrio@users.noreply.github.com>

ENV VERSION 0.31

RUN apk update && apk add bash hostapd iptables dhcp && rm -rf /var/cache/apk/*
RUN echo "" > /var/lib/dhcp/dhcpd.leases
ADD wlanstart.sh /bin/wlanstart.sh

ENTRYPOINT [ "/bin/wlanstart.sh" ]

