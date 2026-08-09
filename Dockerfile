FROM alpine:3.24.1

LABEL maintainer="Sergio R. <sdelrio@users.noreply.github.com>"

ENV VERSION=0.31.0

RUN apk add --no-cache bash hostapd iptables dnsmasq

COPY wlanstart.sh /bin/wlanstart.sh

ENTRYPOINT [ "/bin/wlanstart.sh" ]
