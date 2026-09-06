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
    wpaVersion: '2',
    wpaPassphrase: 'passw0rd',
    showPassphrase: false,
    pmfAuto: true,
    pmf: '0',
    subnet: '192.168.254.0',
    apAddr: '192.168.254.1',
    dhcpRangeAuto: true,
    dhcpRangeStart: '192.168.254.100',
    dhcpRangeEnd: '192.168.254.200',
    dhcpLease: '12h',
    priDns: '8.8.8.8',
    secDns: '8.8.4.4',
    ipv6: false,
    htEnabled: false,
    htCapab: '',
    vhtEnabled: false,
    vhtCapab: '',
    heEnabled: false,
    heCapab: '',
    get availableChannels() {
      const group = _countryGroup[this.countryCode]
      const list = this.hwMode === 'a' ? channels5G : channels2G
      return group ? (list[group] || []) : []
    },

    get subnetPrefix() {
      const parts = this.subnet.split('.')
      parts.length = 3
      return parts.join('.')
    },

    init() {
      const channelSelect = document.getElementById('channel')
      if (channelSelect) {
        channelSelect.innerHTML = `
          <option value="acs">Auto (ACS)</option>
          <template x-for="ch in availableChannels" :key="ch">
            <option :value="ch" x-text="dfsChannels.has(ch) ? ch + ' (DFS)' : ch"></option>
          </template>
        `
      }
      this.$watch('hwMode', (mode) => {
        this._syncChannel()
        if (mode !== 'a') {
          this.vhtEnabled = false
          this.vhtCapab = ''
          this.heEnabled = false
          this.heCapab = ''
        }
      })
      this.$watch('countryCode', () => this._syncChannel())
      this.$watch('wpaVersion', () => { if (this.pmfAuto) this._derivePmf() })
      this.$watch('pmfAuto', (on) => { if (on) this._derivePmf() })
      this.$watch('subnet', () => {
        if (this.dhcpRangeAuto) this._syncDhcpRange()
      })
      this.$watch('dhcpRangeAuto', (on) => { if (on) this._syncDhcpRange() })
    },

    _syncDhcpRange() {
      const prefix = this.subnetPrefix
      this.dhcpRangeStart = prefix + '.100'
      this.dhcpRangeEnd = prefix + '.200'
    },

    _syncChannel() {
      if (this.channel === 'acs') return
      if (!this.availableChannels.includes(parseInt(this.channel, 10))) {
        this.channel = this.availableChannels.length ? String(this.availableChannels[0]) : 'acs'
      }
    },

    _derivePmf() {
      const map = { '2': '0', '3': '2', mixed: '1' }
      this.pmf = map[this.wpaVersion] || '0'
    },

    generateCommand() {
      const channelValue = this.channel === 'acs' ? 'acs' : this.channel
      let cmd = `docker run -d \
  --name rpi-hostap \
  --net=host \
  --cap-add=NET_ADMIN \
  -e SSID=rpi-hostap \
  -e WPA_PASSPHRASE=${this.wpaPassphrase} \
  -e WPA_VERSION=${this.wpaVersion} \
  -e PMF=${this.pmf} \
  -e CHANNEL=${channelValue} \
  -e HW_MODE=${this.hwMode} \
  -e COUNTRY_CODE=${this.countryCode}`
      
      if (this.htEnabled) {
        cmd += ` \\
  -e HT_ENABLED=1`
        if (this.htCapab) {
          cmd += ` \\
  -e HT_CAPAB="${this.htCapab}"`
        }
      }
      
      if (this.vhtEnabled) {
        cmd += ` \\
  -e VHT_ENABLED=1`
        if (this.vhtCapab) {
          cmd += ` \\
  -e VHT_CAPAB="${this.vhtCapab}"`
        }
      }
      
      if (this.heEnabled) {
        cmd += ` \\
  -e HE_ENABLED=1`
        if (this.heCapab) {
          cmd += ` \\
  -e HE_CAPAB="${this.heCapab}"`
        }
      }

      cmd += ` \\
  -e SUBNET=${this.subnet} \\
  -e AP_ADDR=${this.apAddr} \\
  -e PRI_DNS=${this.priDns} \\
  -e SEC_DNS=${this.secDns} \\
  -e DHCP_LEASE=${this.dhcpLease}`

      if (!this.dhcpRangeAuto) {
        cmd += ` \\
  -e DHCP_RANGE=${this.dhcpRangeStart},${this.dhcpRangeEnd},255.255.255.0,${this.dhcpLease}`
      }

      if (this.ipv6) {
        cmd += ` \\
  -e IPV6=1`
      }
      
      cmd += ` \\
  -v /dev/net/tun:/dev/net/tun \\
  sdelrio/rpi-hostap`
      
      return cmd
    }
  }
}
