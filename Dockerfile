FROM alpine:3.24.1

LABEL maintainer="Sergio R. <sdelrio@users.noreply.github.com>"

ENV VERSION=1.0.0-beta.1

RUN apk update && apk add bash hostapd iptables dnsmasq && rm -rf /var/cache/apk/*
ADD wlanstart.sh /bin/wlanstart.sh

ENTRYPOINT [ "/bin/wlanstart.sh" ]

