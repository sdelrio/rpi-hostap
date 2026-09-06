function configAssistant() {
  return {
    hwMode: 'g',
    countryCode: '',
    generateCommand() {
      return `docker run -d \
  --name rpi-hostap \
  --net=host \
  --cap-add=NET_ADMIN \
  -e SSID=rpi-hostap \
  -e WPA_PASSPHRASE=changeme \
  -e CHANNEL=11 \
  -e HW_MODE=${this.hwMode} \
  -e COUNTRY_CODE=${this.countryCode} \
  -v /dev/net/tun:/dev/net/tun \
  sdelrio/rpi-hostap`;
    }
  }
}
