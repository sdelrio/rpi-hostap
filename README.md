# Docker container stack: hostap + dhcp server 

Designed to work on **Raspberry Pi** (arm) using as base image alpine linux (very little size).

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

