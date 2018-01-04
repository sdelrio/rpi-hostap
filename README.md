# Docker container stack: hostap + dhcp server 

Designed to work on **Raspberry Pi** (arm) using as base image alpine linux (very little size).

# Idea


Since my last change on ISP, they put a cable modem with a horrible Wireless, it drops lots of packets, and I didn't want to put an extra AP or wireless router. 

Most of the time use wireless devices on same room so I decided to try to convert my current Pi on a small Access Point using a small USB dongle.


# Requirements

On the host system, the ralink firmware (in my case) should be installed so you can use it on AP mode. On debian/raspbian:

```
apt-get install firmware-ralink
```

Make sure your USB support AP mode:

```
# iw list
...
        Supported interface modes:
                 * IBSS
                 * managed
                 * AP
                 * AP/VLAN
                 * WDS
                 * monitor
                 * mesh point
...
```

Set country regulations, for excample, to Spain set:

```
# iw reg set ES
country ES: DFS-ETSI
        (2400 - 2483 @ 40), (N/A, 20), (N/A)
        (5150 - 5250 @ 80), (N/A, 23), (N/A), NO-OUTDOOR
        (5250 - 5350 @ 80), (N/A, 20), (0 ms), NO-OUTDOOR, DFS
        (5470 - 5725 @ 160), (N/A, 26), (0 ms), DFS
        (57000 - 66000 @ 2160), (N/A, 40), (N/A)
```

# Build / run

For modification, testings, etc.. there is already a `Makefile`. So you can `make run` to start a sample ssid with a simple password.

I've already uploaded the image to docker hubs, so you can run it from ther like this:

```
sudo docker run -d -t \
  -e INTERFACE=wlan0 \
  -e CHANNEL=6 \
  -e SSID=runssid \
  -e APADDR=192.168.254.1 \
  -e SUBNET=192.168.254.0 \
  -e WPA_PASSPHRASE=passw0rd \
  -e OUTGOINGS=eth0 \
  --privileged \
  --net host \
  sdelrio/rpi-hostap:latest
```

But before this, hostap usually requires that wlan0 interface to be already up, so before `docker run` take the interface up:

```
/sbin/ifconfig wlan0 192.168.254.1/24 up
```

Also you should have a driver to enable hostap on your USB wifi

```
apt-get install firmware-ralink
```

# Todo 

Improve README.md

