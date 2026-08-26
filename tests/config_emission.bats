#!/usr/bin/env bats

# Direct tests for the extracted config emission modules (issue #238):
# lib/core/hostapd_conf.sh and lib/core/dnsmasq_conf.sh.

REPO="${BATS_TEST_DIRNAME}/.."

# Load modules with a fixed environment so env_resolve_config_env sees
# the same inputs the assertions below expect.
load_modules() {
    . "${REPO}/lib/bootstrap.sh"
    require_module env hostapd_conf dnsmasq_conf
    export INTERFACE=wlan0 SSID=testnet WPA_PASSPHRASE=supersecret COUNTRY_CODE=US
    env_resolve_config_env >/dev/null 2>&1
}

@test "hostapd_conf_emit generates expected hostapd.conf" {
    load_modules
    hostapd_conf_emit > "${BATS_TMPDIR}/hostapd_actual.conf"
    diff -u /dev/stdin "${BATS_TMPDIR}/hostapd_actual.conf" <<'CONF'
interface=wlan0

ssid=testnet

hw_mode=g
channel=11
country_code=US
wpa=2
wpa_passphrase=supersecret
wpa_key_mgmt=WPA-PSK
# TKIP is no secure anymore
#wpa_pairwise=TKIP CCMP
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_ptk_rekey=600
wmm_enabled=1





# Activate channel selection for HT High Throughput (802.11an)




# Activate channel selection for VHT Very High Throughput (802.11ac)




# Activate channel selection for HE High Efficiency (802.11ax)



CONF
}

@test "hostapd_conf_emit includes optional lines only when enabled" {
    load_modules
    export DRIVER=nl80211 HT_ENABLED=1 HT_CAPAB="[SHORT-GI-20]" \
        MAX_STATIONS=10 AP_ISOLATION=1
    run hostapd_conf_emit
    [ "$status" -eq 0 ]
    [[ "$output" == *"driver=nl80211"* ]]
    [[ "$output" == *"ieee80211n=1"* ]]
    [[ "$output" == *"ht_capab=[SHORT-GI-20]"* ]]
    [[ "$output" == *"max_num_sta=10"* ]]
    [[ "$output" == *"ap_isolate=1"* ]]
}

@test "hostapd_conf_emit emits ieee80211ax and he_capab when HE is enabled" {
    load_modules
    export HW_MODE=a CHANNEL=36 HE_ENABLED=1 HE_CAPAB="[MAX-MPDU-11454][SHORT-GI-80]"
    run hostapd_conf_emit
    [ "$status" -eq 0 ]
    [[ "$output" == *"ieee80211ax=1"* ]]
    [[ "$output" == *"he_capab=[MAX-MPDU-11454][SHORT-GI-80]"* ]]
}

@test "hostapd_conf_emit omits HE lines when unset" {
    load_modules
    export HW_MODE=g
    run hostapd_conf_emit
    [ "$status" -eq 0 ]
    [[ "$output" != *"ieee80211ax"* ]]
    [[ "$output" != *"he_capab"* ]]
}

@test "hostapd_conf_emit fails on invalid WPA_VERSION" {
    load_modules
    export WPA_VERSION=bogus
    run hostapd_conf_emit
    [ "$status" -ne 0 ]
}

@test "dnsmasq_conf_emit generates expected dnsmasq.conf from SUBNET defaults" {
    load_modules
    run dnsmasq_conf_emit
    [ "$status" -eq 0 ]
    diff -u /dev/stdin <(dnsmasq_conf_emit) <<'CONF' 2>/dev/null
interface=wlan0
bind-dynamic
dhcp-authoritative
dhcp-leasefile=/tmp/dnsmasq.leases
dhcp-range=192.168.254.100,192.168.254.200,255.255.255.0,12h
dhcp-option=option:router,192.168.254.1
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4

CONF
}

@test "dnsmasq_conf_emit reuses DHCP_RANGE_COMPUTED when set" {
    load_modules
    export DHCP_RANGE_COMPUTED="10.0.0.10,10.0.0.20,255.255.255.0,24h"
    run dnsmasq_conf_emit
    [ "$status" -eq 0 ]
    [[ "$output" == *"dhcp-range=10.0.0.10,10.0.0.20,255.255.255.0,24h"* ]]
}

@test "dnsmasq_conf_emit adds IPv6 options with IPV6=1" {
    load_modules
    export IPV6=1
    run dnsmasq_conf_emit
    [ "$status" -eq 0 ]
    [[ "$output" == *"dhcp-range=::,constructor:wlan0,ra-names,stateless"* ]]
}

@test "emit functions are not defined by wlanstart.sh itself" {
    ! grep -E '(hostapd|dnsmasq)_conf[a-z_]*\(\)' "${REPO}/wlanstart.sh"
}
