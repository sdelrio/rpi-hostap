#!/usr/bin/env bats

# Tests for env_resolve_config_env() in lib/env.sh - the single place where
# environment defaults are applied (issue #237).

setup() {
    # Start from a clean slate for every defaulted variable
    for var in HW_MODE CHANNEL COUNTRY_CODE SUBNET AP_ADDR PRI_DNS SEC_DNS \
               DHCP_LEASE SSID WPA_PASSPHRASE WPA_VERSION MAX_STATIONS ; do
        unset "${var}"
    done
    # shellcheck source=../lib/env.sh
    . "${BATS_TEST_DIRNAME}/../lib/env.sh"
}

@test "env_resolve_config_env applies all defaults when env is empty" {
    run bash -c '
        . "'"${BATS_TEST_DIRNAME}"'/../lib/env.sh"
        env_resolve_config_env 2>/dev/null
        printf "%s\n" "${HW_MODE}" "${CHANNEL}" "${COUNTRY_CODE}" \
            "${SUBNET}" "${AP_ADDR}" "${PRI_DNS}" "${SEC_DNS}" \
            "${DHCP_LEASE}" "${SSID}" "${WPA_PASSPHRASE}" \
            "${WPA_VERSION}" "${MAX_STATIONS}"
    '
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "g" ]
    [ "${lines[1]}" = "11" ]
    [ "${lines[2]}" = "EU" ]
    [ "${lines[3]}" = "192.168.254.0" ]
    [ "${lines[4]}" = "192.168.254.1" ]
    [ "${lines[5]}" = "8.8.8.8" ]
    [ "${lines[6]}" = "8.8.4.4" ]
    [ "${lines[7]}" = "12h" ]
    [ "${lines[8]}" = "raspberry" ]
    [ "${lines[9]}" = "passw0rd" ]
    [ "${lines[10]}" = "2" ]
    [ "${lines[11]}" = "0" ]
}

@test "env_resolve_config_env never overrides explicitly set variables" {
    run bash -c '
        . "'"${BATS_TEST_DIRNAME}"'/../lib/env.sh"
        export HW_MODE=a CHANNEL=36 COUNTRY_CODE=US SUBNET=10.0.0.0 AP_ADDR=10.0.0.1
        export PRI_DNS=1.1.1.1 SEC_DNS=1.0.0.1 DHCP_LEASE=24h SSID=myssid
        export WPA_PASSPHRASE=supersecret WPA_VERSION=3 MAX_STATIONS=16
        env_resolve_config_env 2>/dev/null
        printf "%s\n" "${HW_MODE}" "${CHANNEL}" "${COUNTRY_CODE}" \
            "${SUBNET}" "${AP_ADDR}" "${PRI_DNS}" "${SEC_DNS}" \
            "${DHCP_LEASE}" "${SSID}" "${WPA_PASSPHRASE}" \
            "${WPA_VERSION}" "${MAX_STATIONS}"
    '
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "a" ]
    [ "${lines[1]}" = "36" ]
    [ "${lines[2]}" = "US" ]
    [ "${lines[3]}" = "10.0.0.0" ]
    [ "${lines[4]}" = "10.0.0.1" ]
    [ "${lines[5]}" = "1.1.1.1" ]
    [ "${lines[6]}" = "1.0.0.1" ]
    [ "${lines[7]}" = "24h" ]
    [ "${lines[8]}" = "myssid" ]
    [ "${lines[9]}" = "supersecret" ]
    [ "${lines[10]}" = "3" ]
    [ "${lines[11]}" = "16" ]
}

@test "env_resolve_config_env warns when COUNTRY_CODE is not set" {
    run env_resolve_config_env
    [ "$status" -eq 0 ]
    [[ "$output" == *"COUNTRY_CODE not set, defaulting to 'EU'"* ]]
}

@test "env_resolve_config_env stays silent when COUNTRY_CODE is set" {
    COUNTRY_CODE=JP
    run env_resolve_config_env
    [ "$status" = 0 ]
    [ "$output" = "" ]
}

# Lib modules must not re-default their own vars (#237): sourcing only
# the module and calling it with an empty environment must fail loudly
# rather than silently resolving defaults.
@test "compute_wpa_conf without resolved env does not apply defaults" {
    . "${BATS_TEST_DIRNAME}/../lib/wpa.sh"
    unset WPA_VERSION
    run compute_wpa_conf
    [ "$status" -ne 0 ]
}

@test "compute_max_sta_conf without MAX_STATIONS errors instead of defaulting" {
    . "${BATS_TEST_DIRNAME}/../lib/stations.sh"
    unset MAX_STATIONS
    run compute_max_sta_conf
    [ "$status" -ne 0 ]
}

@test "validate_channel with unresolved empty env fails loudly" {
    . "${BATS_TEST_DIRNAME}/../lib/channel.sh"
    unset HW_MODE CHANNEL COUNTRY_CODE
    run validate_channel_strict
    [ "$status" -ne 0 ]
}
