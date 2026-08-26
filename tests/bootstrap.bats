#!/usr/bin/env bats
# Declarative module loading via lib/bootstrap.sh (issue #239).

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
    LIB="${ROOT}/lib"
}

@test "bootstrap defines require_module exactly once after double source" {
    run bash -c '
        set -euo pipefail
        . "'"${LIB}"'/bootstrap.sh"
        . "'"${LIB}"'/bootstrap.sh"
        declare -F require_module > /dev/null
    '
    [ "$status" -eq 0 ]
}

@test "require_module resolves core and sys modules" {
    run bash -c '
        set -euo pipefail
        . "'"${LIB}"'/bootstrap.sh"
        require_module validation
        declare -F validation_check_ipv4_param > /dev/null
        require_module nat
        declare -F nat_apply_rules > /dev/null
        [ -n "${_LOADED_validation:-}" ] && [ -n "${_LOADED_nat:-}" ]
    '
    [ "$status" -eq 0 ]
}

@test "require_module is idempotent: double load is a no-op" {
    run bash -c '
        set -euo pipefail
        . "'"${LIB}"'/bootstrap.sh"
        require_module lifecycle
        PHASE_TEARDOWN=()
        # Second call must not re-execute the module body (which would
        # re-append teardown hooks).
        require_module lifecycle
        [ "${#PHASE_TEARDOWN[@]}" -eq 0 ]
    '
    [ "$status" -eq 0 ]
}

@test "require_module accepts multiple modules in one call" {
    run bash -c '
        set -euo pipefail
        . "'"${LIB}"'/bootstrap.sh"
        require_module channel validation nat
        declare -F channel_validate_strict > /dev/null
        declare -F validation_check_ipv4_param > /dev/null
        declare -F nat_apply_rules > /dev/null
    '
    [ "$status" -eq 0 ]
}

@test "dependency resolution: requiring ipv6 loads nat first" {
    run bash -c '
        set -euo pipefail
        . "'"${LIB}"'/bootstrap.sh"
        require_module ipv6
        declare -F nat_parse_outgoings > /dev/null
        declare -F ipv6_compute_dnsmasq_conf > /dev/null
        [ -n "${_LOADED_nat:-}" ]
    '
    [ "$status" -eq 0 ]
}
