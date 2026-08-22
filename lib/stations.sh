# shellcheck shell=bash
# Shared MAX_STATIONS logic used by wlanstart.sh and tests.
#
# compute_max_sta_conf reads MAX_STATIONS from the environment and writes the
# hostapd max_num_sta line to stdout (empty when disabled). Warnings go to
# stderr.
compute_max_sta_conf() {
    : "${MAX_STATIONS:=0}"
    if [ "${MAX_STATIONS}" != "0" ] && ! [ "${MAX_STATIONS}" -gt 0 ] 2>/dev/null ; then
        echo "[Warning] Invalid MAX_STATIONS '${MAX_STATIONS}'. Must be a non-negative integer. Ignoring." >&2
    fi
    _MAX_STA_CONF=""
    if [ "${MAX_STATIONS}" -gt 0 ] 2>/dev/null ; then
        _MAX_STA_CONF="max_num_sta=${MAX_STATIONS}"
    fi
    echo "${_MAX_STA_CONF}"
}
