#!/usr/bin/env bats

# Helper to extract channel/hw_mode validation logic from wlanstart.sh

setup() {
    unset HW_MODE
    unset CHANNEL
}

validate_channel() {
    true ${HW_MODE:=g}
    true ${CHANNEL:=11}

    case "${HW_MODE}" in
        g|b)
            if ! [ "${CHANNEL}" -gt 0 ] 2>/dev/null; then
                echo "[Error] Channel '${CHANNEL}' must be a positive integer" >&2
                return 1
            fi
            if [ "${CHANNEL}" -gt 14 ] 2>/dev/null; then
                echo "[Error] Channel ${CHANNEL} is invalid for hw_mode=${HW_MODE} (max 14)" >&2
                return 1
            fi
            ;;
        a)
            if ! [ "${CHANNEL}" -gt 0 ] 2>/dev/null; then
                echo "[Error] Channel '${CHANNEL}' must be a positive integer" >&2
                return 1
            fi
            if [ "${CHANNEL}" -le 14 ] 2>/dev/null; then
                echo "[Warning] Channel ${CHANNEL} may be invalid for hw_mode=a (5GHz typically > 14)" >&2
            fi
            ;;
        *)
            echo "[Warning] Unknown hw_mode='${HW_MODE}', skipping channel validation" >&2
            ;;
    esac
    return 0
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

@test "hw_mode=g with channel 14 passes" {
    HW_MODE="g"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=g with channel 15 fails" {
    HW_MODE="g"
    CHANNEL="15"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"invalid"* ]]
}

@test "hw_mode=g with channel 36 fails" {
    HW_MODE="g"
    CHANNEL="36"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"invalid"* ]]
}

@test "hw_mode=b with channel 1 passes" {
    HW_MODE="b"
    CHANNEL="1"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=b with channel 14 passes" {
    HW_MODE="b"
    CHANNEL="14"
    run validate_channel
    [ "$status" -eq 0 ]
}

@test "hw_mode=b with channel 15 fails" {
    HW_MODE="b"
    CHANNEL="15"
    run validate_channel
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error"*"invalid"* ]]
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
