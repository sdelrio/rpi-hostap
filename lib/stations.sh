# shellcheck shell=bash
# Shared MAX_STATIONS logic used by wlanstart.sh and tests.
#
# compute_max_sta_conf reads MAX_STATIONS from the environment (default
# applied centrally by lib/env.sh, see issue #237) and writes the
# hostapd max_num_sta line to stdout (empty when disabled). Errors go to
# stderr. Returns non-zero for invalid MAX_STATIONS values.
compute_max_sta_conf() {
    if [ "${MAX_STATIONS}" != "0" ] && ! [ "${MAX_STATIONS}" -gt 0 ] 2>/dev/null ; then
        echo "[Error] Invalid MAX_STATIONS '${MAX_STATIONS}'. Must be a non-negative integer." >&2
        return 1
    fi
    _MAX_STA_CONF=""
    if [ "${MAX_STATIONS}" -gt 0 ] 2>/dev/null ; then
        _MAX_STA_CONF="max_num_sta=${MAX_STATIONS}"
    fi
    echo "${_MAX_STA_CONF}"
}
