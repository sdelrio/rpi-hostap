#!/usr/bin/env bats

# Tests for wlanstart.sh --validate dry-run mode (issue #122)

SCRIPT="${BATS_TEST_DIRNAME}/../wlanstart.sh"

# Run the script in validate mode with a clean environment plus the
# given env assignments.
run_validate() {
    env -i PATH="${PATH}" HOME="${HOME}" "$@" "${SCRIPT}" --validate
}

@test "--validate with valid defaults exits 0 and prints both configs" {
    run run_validate INTERFACE=wlan0 SSID=testnet WPA_PASSPHRASE=supersecret COUNTRY_CODE=US
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== /etc/hostapd.conf ==="* ]]
    [[ "$output" == *"=== /etc/dnsmasq.conf ==="* ]]
    [[ "$output" == *"ssid=testnet"* ]]
    [[ "$output" == *"dhcp-range=192.168.254.100,192.168.254.200,255.255.255.0,12h"* ]]
}

@test "-t alias behaves like --validate" {
    run env -i PATH="${PATH}" INTERFACE=wlan0 SSID=t WPA_PASSPHRASE=supersecret "${SCRIPT}" -t
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== /etc/hostapd.conf ==="* ]]
}

@test "--test alias behaves like --validate" {
    run env -i PATH="${PATH}" INTERFACE=wlan0 SSID=t WPA_PASSPHRASE=supersecret "${SCRIPT}" --test
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== /etc/hostapd.conf ==="* ]]
}

@test "--validate performs zero system mutations" {
    # Shadow every system-mutating tool with a stub that fails loudly;
    # validate mode must succeed without ever invoking any of them.
    local stubdir="${BATS_TMPDIR}/validate-mode-stubs"
    mkdir -p "${stubdir}"
    local tool
    for tool in ip iptables ip6tables sysctl ifconfig multirun dnsmasq hostapd ; do
        printf '#!/bin/bash\necho "[Error] %s must not be called in validate mode" >&2\nexit 99\n' "${tool}" > "${stubdir}/${tool}"
        chmod +x "${stubdir}/${tool}"
    done
    run env -i PATH="${stubdir}:/usr/bin:/bin" HOME="${HOME}" INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret "${SCRIPT}" --validate
    [ "$status" -eq 0 ]
    [[ "$output" != *"must not be called in validate mode"* ]]
}

@test "--validate bypasses privileged mode check (no /sys writability error)" {
    run run_validate INTERFACE=wlan0 SSID=x WPA_PASSPHRASE=supersecret
    [ "$status" -eq 0 ]
    [[ "$output" != *"Not running in privileged mode."* ]]
}

@test "--validate rejects missing INTERFACE" {
    run run_validate SSID=x WPA_PASSPHRASE=supersecret
    [ "$status" -ne 0 ]
    [[ "$output" == *"An interface must be specified."* ]]
}

@test "--validate rejects invalid channel" {
    run run_validate INTERFACE=wlan0 COUNTRY_CODE=US CHANNEL=13 SSID=x WPA_PASSPHRASE=supersecret
    [ "$status" -ne 0 ]
    [[ "$output" == *"Channel 13 not allowed for country US"* ]]
    [[ "$output" != *"=== /etc/hostapd.conf ==="* ]]
}

@test "--validate rejects short passphrase" {
    run run_validate INTERFACE=wlan0 WPA_PASSPHRASE=short SSID=x
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid WPA_PASSPHRASE"* ]]
}

@test "--validate rejects invalid SUBNET" {
    run run_validate INTERFACE=wlan0 SUBNET=not-an-ip SSID=x WPA_PASSPHRASE=supersecret
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SUBNET"* ]]
}

@test "--validate rejects invalid AP_ADDR" {
    run run_validate INTERFACE=wlan0 AP_ADDR=999.1.1.1 SSID=x WPA_PASSPHRASE=supersecret
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid AP_ADDR"* ]]
}

@test "--validate rejects bad DHCP_RANGE" {
    run run_validate INTERFACE=wlan0 DHCP_RANGE="oops" SSID=x WPA_PASSPHRASE=supersecret
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid DHCP_RANGE format"* ]]
}

@test "--validate collects multiple failures instead of first-fail" {
    run run_validate INTERFACE="" CHANNEL=99 COUNTRY_CODE=US WPA_PASSPHRASE=short SSID=x
    [ "$status" -ne 0 ]
    [[ "$output" == *"An interface must be specified."* ]]
    [[ "$output" == *"Channel 99 not allowed"* ]]
    [[ "$output" == *"Invalid WPA_PASSPHRASE"* ]]
    [[ "$output" == *"error(s)"* ]]
}

@test "--validate rejects MAC_FILTER without MAC_ACL_FILE" {
    run run_validate INTERFACE=wlan0 MAC_FILTER=1 SSID=x WPA_PASSPHRASE=supersecret
    [ "$status" -ne 0 ]
    [[ "$output" == *"MAC_FILTER=1 requires MAC_ACL_FILE"* ]]
}

@test "--validate accepts MAC_FILTER with MAC_ACL_FILE" {
    run run_validate INTERFACE=wlan0 MAC_FILTER=2 MAC_ACL_FILE=/etc/hostapd.accept SSID=x WPA_PASSPHRASE=supersecret
    [ "$status" -eq 0 ]
    [[ "$output" == *"deny_mac_file=/etc/hostapd.accept"* ]]
}

@test "--validate unknown option exits non-zero" {
    run bash -c "'${SCRIPT}' --bogus"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
}
