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

@test "circular dependency detection produces error and non-zero exit" {
    run bash -c '
        set -euo pipefail
        . "'"${LIB}"'/bootstrap.sh"
        MODULE_DEPENDENCIES_circ_a="circ_b"
        MODULE_DEPENDENCIES_circ_b="circ_a"
        # Create stub module files so the loader does not fail on missing files
        mkdir -p "'"${LIB}"'/core"
        echo "# stub" > "'"${LIB}"'/core/circ_a.sh"
        echo "# stub" > "'"${LIB}"'/core/circ_b.sh"
        require_module circ_a
    '
    [ "$status" -ne 0 ]
    [[ "$output" == *"Circular dependency detected"* ]]
    # Cleanup stubs
    rm -f "${LIB}/core/circ_a.sh" "${LIB}/core/circ_b.sh"
}

@test "existing module loading still works (no false positives from resolving guard)" {
    run bash -c '
        set -euo pipefail
        . "'"${LIB}"'/bootstrap.sh"
        require_module validation nat ipv6
        declare -F validation_check_ipv4_param > /dev/null
        declare -F nat_apply_rules > /dev/null
        declare -F ipv6_compute_dnsmasq_conf > /dev/null
    '
    [ "$status" -eq 0 ]
}
