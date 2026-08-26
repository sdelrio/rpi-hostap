# shellcheck shell=bash
# Phase-based lifecycle with registered setup/teardown hooks (issue #241).
#
# Modules register callbacks into named phase arrays at source time instead
# of wlanstart.sh hardcoding every feature's setup/teardown. A new module
# can add behaviour by sourcing lib/lifecycle.sh and appending to the
# relevant PHASE_* array (or calling lifecycle_register) - no edits to
# wlanstart.sh needed.
#
# Phases (arrays): pre_validate, validate, pre_setup, post_setup, teardown.
#
# Registration order within a phase is execution order:
#   - setup-ish phases: register in dependency order (dependencies first)
#   - teardown: register in reverse-dependency order, i.e. the exact order
#     teardown must run in (most-dependent feature torn down first). The
#     current registration is nat -> ipv6 -> interface, matching the
#     historical hardcoded cleanup() sequence.
#
# lifecycle_run_phase iterates a phase array in order and stops on the
# first failing hook, returning non-zero. Teardown runs exactly once per
# process thanks to _TEARDOWN_DONE, even when a signal arrives mid-setup.
#
# Written for maximum bash portability (no ${var^^}, no namerefs, no
# declare: plain assignments keep the phase arrays global even when this
# file is sourced from inside a function, as bats test helpers do).

# shellcheck disable=SC2034  # phase arrays are populated by modules, read via eval
PHASE_PRE_VALIDATE=()
PHASE_VALIDATE=()
PHASE_PRE_SETUP=()
PHASE_POST_SETUP=()
PHASE_TEARDOWN=()

_TEARDOWN_DONE=0

# _lifecycle_upper_phase prints the given phase name uppercased.
_lifecycle_upper_phase() {
    printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

# lifecycle_register adds a hook function to the named phase
# (e.g. lifecycle_register teardown nat_remove_rules).
lifecycle_register() {
    local phase="$1" hook="$2" up
    up=$(_lifecycle_upper_phase "${phase}")
    eval "PHASE_${up}+=(\"\${hook}\")"
}

# lifecycle_run_phase runs every hook registered for the named phase, in
# registration order, stopping at and returning the first failure.
lifecycle_run_phase() {
    local phase="$1" up
    up=$(_lifecycle_upper_phase "${phase}")
    # shellcheck disable=SC2034,SC2317  # hook is assigned/read via eval below
    local hook
    # ${arr[@]+...} keeps the expansion safe on empty arrays under set -u
    eval "for hook in \${PHASE_${up}[@]+\"\${PHASE_${up}[@]}\"} ; do
        \"\${hook}\" || return 1
    done"
}

# lifecycle_run_teardown executes the teardown phase exactly once, no
# matter how many times it is invoked (signal during startup, normal
# exit after multirun, ...). Subsequent calls are no-ops.
lifecycle_run_teardown() {
    [ "${_TEARDOWN_DONE}" = "0" ] || return 0
    _TEARDOWN_DONE=1
    lifecycle_run_phase teardown
}
