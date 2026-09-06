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
    ssid: 'raspberry',
    hideSsid: false,
    maxStations: '0',
    apIsolation: false,
    macFilter: '0',
    macAclFile: '',
    txPower: '',
    interface: 'wlan0',
    driver: '',
    htEnabled: false,
    htCapab: '',
    vhtEnabled: false,
    vhtCapab: '',
    heEnabled: false,
    heCapab: '',
    showAllVars: false,
    copied: false,
    containerName: 'rpi-hostap',
    copiedDocker: false,

    get envFileOutput() {
      const defaults = {
        SSID: 'raspberry',
        WPA_PASSPHRASE: 'passw0rd',
        WPA_VERSION: '2',
        HW_MODE: 'g',
        CHANNEL: 'acs',
        COUNTRY_CODE: '',
        SUBNET: '192.168.254.0',
        AP_ADDR: '192.168.254.1',
        PRI_DNS: '8.8.8.8',
        SEC_DNS: '8.8.4.4',
        DHCP_LEASE: '12h',
        INTERFACE: 'wlan0',
      }

      const allVars = {
        SSID: this.ssid,
        WPA_PASSPHRASE: this.wpaPassphrase,
        WPA_VERSION: this.wpaVersion,
        PMF: this.pmf,
        HW_MODE: this.hwMode,
        CHANNEL: this.channel === 'acs' ? 'acs' : this.channel,
        COUNTRY_CODE: this.countryCode,
        SUBNET: this.subnet,
        AP_ADDR: this.apAddr,
        PRI_DNS: this.priDns,
        SEC_DNS: this.secDns,
        DHCP_LEASE: this.dhcpLease,
        INTERFACE: this.interface,
      }

      if (this.hideSsid) allVars.HIDE_SSID = '1'
      if (this.apIsolation) allVars.AP_ISOLATION = '1'
      if (this.maxStations && this.maxStations !== '0') allVars.MAX_STATIONS = this.maxStations
      if (this.macFilter !== '0') {
        allVars.MAC_FILTER = this.macFilter
        allVars.MAC_ACL_FILE = this.macAclFile
      }
      if (this.txPower) allVars.TX_POWER = this.txPower
      if (this.driver) allVars.DRIVER = this.driver
      if (this.htEnabled) {
        allVars.HT_ENABLED = '1'
        if (this.htCapab) allVars.HT_CAPAB = this.htCapab
      }
      if (this.vhtEnabled) {
        allVars.VHT_ENABLED = '1'
        if (this.vhtCapab) allVars.VHT_CAPAB = this.vhtCapab
      }
      if (this.heEnabled) {
        allVars.HE_ENABLED = '1'
        if (this.heCapab) allVars.HE_CAPAB = this.heCapab
      }
      if (this.ipv6) allVars.IPV6 = '1'

      const vars = this.showAllVars
        ? Object.entries(allVars)
        : Object.entries(allVars).filter(([k, v]) => defaults[k] !== v)

      if (vars.length === 0 && !this.showAllVars) return '# No non-default values'

      return vars.map(([k, v]) => `${k}=${v}`).join('\n')
    },

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

    get dockerRunCommand() {
      const defaults = {
        SSID: 'raspberry',
        WPA_PASSPHRASE: 'passw0rd',
        WPA_VERSION: '2',
        HW_MODE: 'g',
        CHANNEL: 'acs',
        COUNTRY_CODE: '',
        SUBNET: '192.168.254.0',
        AP_ADDR: '192.168.254.1',
        PRI_DNS: '8.8.8.8',
        SEC_DNS: '8.8.4.4',
        DHCP_LEASE: '12h',
        INTERFACE: 'wlan0',
      }

      const allVars = {
        SSID: this.ssid,
        WPA_PASSPHRASE: this.wpaPassphrase,
        WPA_VERSION: this.wpaVersion,
        PMF: this.pmf,
        HW_MODE: this.hwMode,
        CHANNEL: this.channel === 'acs' ? 'acs' : this.channel,
        COUNTRY_CODE: this.countryCode,
        SUBNET: this.subnet,
        AP_ADDR: this.apAddr,
        PRI_DNS: this.priDns,
        SEC_DNS: this.secDns,
        DHCP_LEASE: this.dhcpLease,
        INTERFACE: this.interface,
      }

      if (this.hideSsid) allVars.HIDE_SSID = '1'
      if (this.apIsolation) allVars.AP_ISOLATION = '1'
      if (this.maxStations && this.maxStations !== '0') allVars.MAX_STATIONS = this.maxStations
      if (this.macFilter !== '0') {
        allVars.MAC_FILTER = this.macFilter
        allVars.MAC_ACL_FILE = this.macAclFile
      }
      if (this.txPower) allVars.TX_POWER = this.txPower
      if (this.driver) allVars.DRIVER = this.driver
      if (this.htEnabled) {
        allVars.HT_ENABLED = '1'
        if (this.htCapab) allVars.HT_CAPAB = this.htCapab
      }
      if (this.vhtEnabled) {
        allVars.VHT_ENABLED = '1'
        if (this.vhtCapab) allVars.VHT_CAPAB = this.vhtCapab
      }
      if (this.heEnabled) {
        allVars.HE_ENABLED = '1'
        if (this.heCapab) allVars.HE_CAPAB = this.heCapab
      }
      if (this.ipv6) allVars.IPV6 = '1'

      const nonDefault = Object.entries(allVars).filter(([k, v]) => defaults[k] !== v)

      const envFlags = nonDefault.map(([k, v]) => `-e ${k}=${v}`).join(' \\\n  ')

      let cmd = `docker run -d \\\n  --privileged \\\n  --net host \\\n  --name ${this.containerName} \\`

      if (envFlags) {
        cmd += `\n  ${envFlags} \\`
      }

      cmd += `\n  ghcr.io/sdelrio/rpi-hostap`

      return cmd
    },

    generateCommand() {
      return this.dockerRunCommand
    },

    copyToClipboard() {
      const output = this.envFileOutput
      navigator.clipboard.writeText(output).then(() => {
        this.copied = true
        setTimeout(() => { this.copied = false }, 2000)
      })
    },

    copyDockerCommand() {
      navigator.clipboard.writeText(this.dockerRunCommand).then(() => {
        this.copiedDocker = true
        setTimeout(() => { this.copiedDocker = false }, 2000)
      })
    },

    toggleShowAll() {
      this.showAllVars = !this.showAllVars
    }
  }
}
