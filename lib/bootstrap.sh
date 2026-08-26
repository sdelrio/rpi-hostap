# shellcheck shell=bash
# Declarative module loading for lib/ (issue #239).
#
# Usage:
#   . "$(dirname "$0")/lib/bootstrap.sh"
#   require_module lifecycle nat interface ...
#
# require_module() sources a module exactly once per process (_LOADED_*
# tracking), resolving core/ vs sys/ automatically, and pulls declared
# dependencies first.
#
# Loaded state and dependencies are tracked in dynamic variables
# (_LOADED_<module>, MODULE_DEPENDENCIES_<module>) rather than
# associative arrays so the loader also works on bash 3.2 (macOS).
#
# Sourcing this file twice is safe and cheap.

if ! declare -F require_module > /dev/null 2>&1 ; then

    LIB_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Cross-module dependencies: MODULE_DEPENDENCIES_<module> holds a
    # space-separated list of modules that must be loaded first.
    # shellcheck disable=SC2034  # read dynamically via ${!deps_var}
    MODULE_DEPENDENCIES_ipv6="nat"

    # Config emission modules (issue #238) pull their compute helpers
    # transitively via the loader.
    MODULE_DEPENDENCIES_hostapd_conf="wpa ap_isolation ssid_hidden mac_filter stations ctrl_interface extra_opts"
    MODULE_DEPENDENCIES_dnsmasq_conf="dhcp ipv6"

    # require_module loads lib/{core,sys}/<module>.sh once, recursively
    # satisfying declared dependencies first. Accepts one or more module
    # names: require_module lifecycle nat interface
    require_module() {
        local m
        for m in "$@" ; do
            _require_one_module "$m"
        done
    }

    _require_one_module() {
        local m=$1
        local loaded_var="_LOADED_${m}"
        [ -n "${!loaded_var:-}" ] && return 0
        local deps_var="MODULE_DEPENDENCIES_${m}"
        local dep
        for dep in ${!deps_var:-} ; do
            require_module "$dep"
        done
        local layer=core
        [ -f "${LIB_BOOTSTRAP_DIR}/sys/${m}.sh" ] && layer=sys
        # shellcheck disable=SC1090
        . "${LIB_BOOTSTRAP_DIR}/${layer}/${m}.sh"
        eval "${loaded_var}=1"
    }

fi
