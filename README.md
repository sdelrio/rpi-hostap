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

# Build / run

For modification, testings, etc.. there is already a `Makefile`. So you can `make run` to start a sample ssid with a simple password.

I've already uploaded the image to docker hubs, so you can run it from ther like this:

```
sudo docker run -d -t \
  -e INTERFACE=wlan0 \
  -e CHANNEL=6 \
  - e SSID=runssid \
  -e APADDR=192.168.254.1 \
  -e SUBNET=192.168.254.0 \
  -e WPA_PASSPHRASE=passw0rd \
  -e OUTGOINGS=eth0 \
  --privileged \
  --net host \
  sdelrio/rpi-hostap:latest
```

But before this hostap usually requires that wlan0 interface should had been already up, so 

/sbin/ifconfig wlan0 192.168.254.1/24 up

Also you should have a driver to enable hostap on your USB wifi

```
apt-get install firmware-ralink
```

# Todo 

Improve README.md

