#!/usr/bin/env bats

# Tests exercise validation_check_ipv4() from lib/core/validation.sh — the exact
# code used by wlanstart.sh (no duplicated logic).

load_lib() {
    . "${BATS_TEST_DIRNAME}/../lib/core/validation.sh"
}

# wlanstart-level check: exercise validation_check_ipv4_param, the exact helper
# used by wlanstart.sh for SUBNET/AP_ADDR.
run_wlanstart_validation() {
    bash -c "
. '${BATS_TEST_DIRNAME}/../lib/core/validation.sh'
validation_check_ipv4_param SUBNET \"\${SUBNET}\" || exit 1
validation_check_ipv4_param AP_ADDR \"\${AP_ADDR}\" || exit 1
" 2>&1
}

@test "valid IPv4 addresses are accepted" {
    load_lib
    for addr in 192.168.254.0 192.168.254.1 8.8.8.8 0.0.0.0 255.255.255.255 10.0.0.1 ; do
        run validation_check_ipv4 "${addr}"
        [ "$status" -eq 0 ]
    done
}

@test "letters are rejected" {
    load_lib
    run validation_check_ipv4 "192.168.abc.1"
    [ "$status" -ne 0 ]
}

@test "octets above 255 are rejected" {
    load_lib
    run validation_check_ipv4 "192.168.256.1"
    [ "$status" -ne 0 ]
    run validation_check_ipv4 "300.168.0.1"
    [ "$status" -ne 0 ]
}

@test "wrong octet count is rejected" {
    load_lib
    run validation_check_ipv4 "192.168.0"
    [ "$status" -ne 0 ]
    run validation_check_ipv4 "192.168.0.1.5"
    [ "$status" -ne 0 ]
}

@test "empty value is rejected" {
    load_lib
    run validation_check_ipv4 ""
    [ "$status" -ne 0 ]
    run validation_check_ipv4
    [ "$status" -ne 0 ]
}

@test "leading-zero octets are rejected" {
    load_lib
    run validation_check_ipv4 "192.168.01.1"
    [ "$status" -ne 0 ]
}

@test "missing octets between dots is rejected" {
    load_lib
    run validation_check_ipv4 "192..0.1"
    [ "$status" -ne 0 ]
}

@test "invalid SUBNET aborts with error before system changes" {
    SUBNET="not.an.ip.addr" AP_ADDR="192.168.254.1" run run_wlanstart_validation
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid SUBNET"* ]]
}

@test "invalid AP_ADDR aborts with error before system changes" {
    SUBNET="192.168.254.0" AP_ADDR="192.168.254.999" run run_wlanstart_validation
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid AP_ADDR"* ]]
}

@test "valid SUBNET and AP_ADDR pass validation" {
    SUBNET="192.168.254.0" AP_ADDR="192.168.254.1" run run_wlanstart_validation
    [ "$status" -eq 0 ]
}

@test "validation_netmask_to_prefix converts common masks" {
    load_lib
    for pair in "255.255.255.0:24" "255.255.0.0:16" "255.0.0.0:8" "0.0.0.0:0" "255.255.255.255:32" "255.255.255.240:28" "255.255.255.128:25" "255.255.240.0:20" ; do
        mask="${pair%:*}"
        want="${pair#*:}"
        run validation_netmask_to_prefix "${mask}"
        [ "$status" -eq 0 ]
        [ "${output}" = "${want}" ]
    done
}

@test "validation_netmask_to_prefix rejects invalid masks" {
    load_lib
    for mask in 255.0.255.0 255.255.0.255 255.255.255.1 255.255.255.3 not-a-mask 255.0.0 "192.168.256.0" ; do
        run validation_netmask_to_prefix "${mask}"
        [ "$status" -ne 0 ]
    done
}

@test "validation_is_network_address accepts network addresses matching the mask" {
    load_lib
    for pair in "192.168.254.0:255.255.255.0" "192.168.254.16:255.255.255.240" "10.0.0.0:255.0.0.0" ; do
        addr="${pair%%:*}"
        mask="${pair#*:}"
        run validation_is_network_address "${addr}" "${mask}"
        [ "$status" -eq 0 ]
    done
}

@test "validation_is_network_address rejects host bits set" {
    load_lib
    for pair in "192.168.254.7:255.255.255.0" "192.168.254.17:255.255.255.240" "10.1.0.0:255.0.0.0" ; do
        addr="${pair%%:*}"
        mask="${pair#*:}"
        run validation_is_network_address "${addr}" "${mask}"
        [ "$status" -ne 0 ]
    done
}
