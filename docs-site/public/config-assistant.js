const channels2G = {
  US: [1,2,3,4,5,6,7,8,9,10,11],
  CA: [1,2,3,4,5,6,7,8,9,10,11],
  MX: [1,2,3,4,5,6,7,8,9,10,11],
  JP: [1,2,3,4,5,6,7,8,9,10,11,12,13,14],
  AU: [1,2,3,4,5,6,7,8,9,10,11,12,13],
  EU: [1,2,3,4,5,6,7,8,9,10,11,12,13],
}
const channels5G = {
  US: [36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,144,149,153,157,161,165],
  CA: [36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,144,149,153,157,161,165],
  MX: [36,40,44,48,52,56,60,64,149,153,157,161,165],
  JP: [36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140],
  AU: [36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140],
  EU: [36,40,44,48,52,56,60,64,100,104,108,112,116,120,124,128,132,136,140],
}
const dfsChannels = new Set([52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,144])

const _countryGroup = {
  US: 'US', CA: 'CA', MX: 'MX', JP: 'JP', AU: 'AU',
  GB: 'EU', DE: 'EU', FR: 'EU', IT: 'EU', ES: 'EU', NL: 'EU', BE: 'EU',
  AT: 'EU', PT: 'EU', IE: 'EU', FI: 'EU', SE: 'EU', DK: 'EU', NO: 'EU',
  PL: 'EU', CZ: 'EU', RO: 'EU', HU: 'EU', BG: 'EU', HR: 'EU', SK: 'EU',
  SI: 'EU', LT: 'EU', LV: 'EU', EE: 'EU', CY: 'EU', LU: 'EU', MT: 'EU',
  GR: 'EU', CH: 'EU',
}

function configAssistant() {
  return {
    hwMode: 'g',
    countryCode: '',
    channel: '11',
    dfsChannels,

    get availableChannels() {
      const group = _countryGroup[this.countryCode] || this.countryCode
      if (this.hwMode === 'a') {
        return channels5G[group] || channels5G.US
      }
      return channels2G[group] || channels2G.US
    },

    init() {
      this.$watch('hwMode', () => this._syncChannel())
      this.$watch('countryCode', () => this._syncChannel())
      this._rebuildChannelOptions()
    },

    _rebuildChannelOptions() {
      const select = document.getElementById('channel')
      if (!select) return
      select.querySelectorAll('option:not([value="acs"])').forEach(o => o.remove())
      this.availableChannels.forEach(ch => {
        const opt = document.createElement('option')
        opt.value = ch
        opt.textContent = dfsChannels.has(ch) ? ch + ' (DFS)' : ch
        select.appendChild(opt)
      })
    },

    _syncChannel() {
      this._rebuildChannelOptions()
      if (this.channel === 'acs') return
      const num = parseInt(this.channel, 10)
      if (!this.availableChannels.includes(num)) {
        this.channel = '11'
      }
    },

    generateCommand() {
      const channelValue = this.channel === 'acs' ? 'acs' : this.channel
      return `docker run -d \
  --name rpi-hostap \
  --net=host \
  --cap-add=NET_ADMIN \
  -e SSID=rpi-hostap \
  -e WPA_PASSPHRASE=changeme \
  -e CHANNEL=${channelValue} \
  -e HW_MODE=${this.hwMode} \
  -e COUNTRY_CODE=${this.countryCode} \
  -v /dev/net/tun:/dev/net/tun \
  sdelrio/rpi-hostap`
    }
  }
}
