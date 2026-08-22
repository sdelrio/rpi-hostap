#!/usr/bin/env bats

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
    unset HW_MODE
    unset CHANNEL
    unset COUNTRY_CODE
    # shellcheck source=../lib/channel.sh
    . "${ROOT}/lib/channel.sh"
}

# --- g/b mode (2.4 GHz) ---

@test "default values pass validation" {
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=g with channel 1 passes" {
    HW_MODE="g"
    CHANNEL="1"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=g with channel 13 passes (EU default)" {
    HW_MODE="g"
    CHANNEL="13"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=g with channel 14 fails (EU default)" {
    HW_MODE="g"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"not allowed"* ]]
}

@test "hw_mode=g with channel 36 fails" {
    HW_MODE="g"
    CHANNEL="36"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"not allowed"* ]]
}

@test "hw_mode=b with channel 1 passes" {
    HW_MODE="b"
    CHANNEL="1"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=b with channel 13 passes (EU default)" {
    HW_MODE="b"
    CHANNEL="13"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=b with channel 14 fails (EU default)" {
    HW_MODE="b"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"not allowed"* ]]
}

# --- a mode (5 GHz) ---

@test "hw_mode=a with channel 36 passes" {
    HW_MODE="a"
    CHANNEL="36"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=a with channel 140 passes" {
    HW_MODE="a"
    CHANNEL="140"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=a with channel 11 issues warning" {
    HW_MODE="a"
    CHANNEL="11"
    run validate_channel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"may be invalid"* ]]
}

@test "hw_mode=a with channel 1 issues warning" {
    HW_MODE="a"
    CHANNEL="1"
    run validate_channel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"may be invalid"* ]]
}

# --- non-numeric channel ---

@test "non-numeric channel with hw_mode=g fails" {
    HW_MODE="g"
    CHANNEL="foo"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"positive integer"* ]]
}

@test "non-numeric channel with hw_mode=a fails" {
    HW_MODE="a"
    CHANNEL="bar"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"positive integer"* ]]
}

@test "non-numeric channel with hw_mode=b fails" {
    HW_MODE="b"
    CHANNEL="baz"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"positive integer"* ]]
}

# --- unknown hw_mode ---

@test "unknown hw_mode issues warning and passes" {
    HW_MODE="x"
    CHANNEL="1"
    run validate_channel
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"*"Unknown hw_mode"* ]]
}

# --- country/regulatory domain validation ---

@test "US allows channel 11 but rejects 12" {
    COUNTRY_CODE="US"
    HW_MODE="g"
    CHANNEL="11"
    run validate_channel
    [ "$status" -eq 0 ]
    CHANNEL="12"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"not allowed for country US"* ]]
}

@test "CA rejects channel 12" {
    COUNTRY_CODE="CA"
    HW_MODE="g"
    CHANNEL="12"
    run validate_channel
    [ "$status" -eq 1 ]
}

@test "MX rejects channel 13" {
    COUNTRY_CODE="MX"
    HW_MODE="b"
    CHANNEL="13"
    run validate_channel
    [ "$status" -eq 1 ]
}

@test "EU allows channels 1-13 but rejects 14" {
    COUNTRY_CODE="EU"
    HW_MODE="g"
    for ch in 1 6 11 13; do
        CHANNEL="${ch}"
        run validate_channel
        [ "$status" -eq 0 ]
    done
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"not allowed for country EU"* ]]
}

@test "UK/ES/DE treated as Europe (max 13)" {
    for cc in UK ES DE; do
        COUNTRY_CODE="${cc}"
        HW_MODE="g"
        CHANNEL="13"
        run validate_channel
        [ "$status" -eq 0 ]
        CHANNEL="14"
        run validate_channel
        [ "$status" -eq 1 ]
    done
}

@test "JP allows channels 1-14" {
    COUNTRY_CODE="JP"
    HW_MODE="g"
    for ch in 1 6 12 13 14; do
        CHANNEL="${ch}"
        run validate_channel
        [ "$status" -eq 0 ]
    done
}

@test "unknown country falls back to EU limits (max 13)" {
    COUNTRY_CODE="ZZ"
    HW_MODE="g"
    CHANNEL="13"
    run validate_channel
    [ "$status" -eq 0 ]
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
}

@test "default region is EU (channel 14 rejected without COUNTRY_CODE)" {
    HW_MODE="g"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"country EU"* ]]
}
