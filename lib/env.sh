# shellcheck shell=bash
# Centralized environment defaults (issue #237).
#
# resolve_config_env() is the single place where default values are
# applied for every configuration variable. It is called exactly once by
# wlanstart.sh, before any validation or config emission, so that
# normal mode and --validate mode always resolve identical configs.
#
# Precedence: an explicitly set environment variable always wins; the
# defaults below only apply when the variable is unset or empty.
# Library modules (lib/*.sh) read these variables and must NOT apply
# their own defaults - they can assume resolve_config_env() has run.

resolve_config_env() {
    # Wireless hardware mode: b | g | a (see lib/channel.sh)
    : "${HW_MODE:=g}"
    # Channel; "acs" enables automatic channel selection
    : "${CHANNEL:=11}"
    # Regulatory domain. Warn when defaulted: channel availability
    # differs per country (e.g. US allows 1-11, EU 1-13).
    if [ -z "${COUNTRY_CODE+x}" ] ; then
        echo "[Warning] COUNTRY_CODE not set, defaulting to 'EU' (ETSI: channels 1-13)." >&2
        echo "          Set COUNTRY_CODE (e.g. US, CA, JP) to match your local regulations." >&2
    fi
    : "${COUNTRY_CODE:=EU}"
    # Network layout
    : "${SUBNET:=192.168.254.0}"
    : "${AP_ADDR:=192.168.254.1}"
    : "${PRI_DNS:=8.8.8.8}"
    : "${SEC_DNS:=8.8.4.4}"
    # DHCP pool lease time used when DHCP_RANGE is not set explicitly
    : "${DHCP_LEASE:=12h}"
    # Access point credentials
    : "${SSID:=raspberry}"
    : "${WPA_PASSPHRASE:=passw0rd}"
    # WPA version: 2 | 3 | mixed (see lib/wpa.sh)
    : "${WPA_VERSION:=2}"
    # Maximum associated stations; 0 means hostapd default (unlimited)
    : "${MAX_STATIONS:=0}"
}
