#!/usr/bin/env bats

# Tests exercise secret_file_load() from lib/core/secret_file.sh - the exact
# code used by wlanstart.sh (no duplicated logic).

setup() {
    unset SSID SSID_FILE WPA_PASSPHRASE WPA_PASSPHRASE_FILE
    SECRET_FILE="${BATS_TEST_TMPDIR}/secret.txt"
}

load_lib() {
    . "${BATS_TEST_DIRNAME}/../lib/core/secret_file.sh"
}

@test "SSID_FILE loads value from first line of file" {
    load_lib
    printf 'myssid\notherline\n' > "${SECRET_FILE}"
    SSID_FILE="${SECRET_FILE}"
    secret_file_load SSID SSID_FILE
    [ "${SSID}" = "myssid" ]
}

@test "WPA_PASSPHRASE_FILE loads passphrase from file" {
    load_lib
    printf 'sup3rs3cret\n' > "${SECRET_FILE}"
    WPA_PASSPHRASE_FILE="${SECRET_FILE}"
    secret_file_load WPA_PASSPHRASE WPA_PASSPHRASE_FILE
    [ "${WPA_PASSPHRASE}" = "sup3rs3cret" ]
}

@test "_FILE wins when both direct var and _FILE are set" {
    load_lib
    printf 'fromfile\n' > "${SECRET_FILE}"
    SSID=direct
    SSID_FILE="${SECRET_FILE}"
    secret_file_load SSID SSID_FILE 2> "${BATS_TEST_TMPDIR}/stderr"
    [ "${SSID}" = "fromfile" ]
    grep -q "using value from SSID_FILE" "${BATS_TEST_TMPDIR}/stderr"
}

@test "warning is emitted when both var and _FILE are set" {
    load_lib
    printf 'fromfile\n' > "${SECRET_FILE}"
    WPA_PASSPHRASE=direct
    WPA_PASSPHRASE_FILE="${SECRET_FILE}"
    run secret_file_load WPA_PASSPHRASE WPA_PASSPHRASE_FILE
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Warning] Both WPA_PASSPHRASE and WPA_PASSPHRASE_FILE are set"* ]]
}

@test "unset _FILE variable leaves target unchanged" {
    load_lib
    SSID=direct
    unset SSID_FILE
    run secret_file_load SSID SSID_FILE
    [ "$status" -eq 0 ]
    [ "${SSID}" = "direct" ]
}

@test "missing file fails with clear error" {
    load_lib
    SSID_FILE="${BATS_TEST_TMPDIR}/does-not-exist"
    run secret_file_load SSID SSID_FILE
    [ "$status" -ne 0 ]
    [[ "$output" == *"[Error] SSID_FILE '${BATS_TEST_TMPDIR}/does-not-exist' is not readable"* ]]
}

@test "unreadable file fails with clear error" {
    load_lib
    printf 'secret\n' > "${SECRET_FILE}"
    chmod 000 "${SECRET_FILE}"
    if [ -r "${SECRET_FILE}" ] ; then
        skip "cannot make file unreadable (running as root)"
    fi
    WPA_PASSPHRASE_FILE="${SECRET_FILE}"
    run secret_file_load WPA_PASSPHRASE WPA_PASSPHRASE_FILE
    [ "$status" -ne 0 ]
    [[ "$output" == *"is not readable"* ]]
}

@test "value loaded from file passes existing validation" {
    load_lib
    . "${BATS_TEST_DIRNAME}/../lib/core/passphrase.sh"
    printf 'passw0rd-from-file\n' > "${SECRET_FILE}"
    WPA_PASSPHRASE_FILE="${SECRET_FILE}"
    secret_file_load WPA_PASSPHRASE WPA_PASSPHRASE_FILE
    [ "${WPA_PASSPHRASE}" = "passw0rd-from-file" ]
    run passphrase_validate
    [ "$status" -eq 0 ]
}
