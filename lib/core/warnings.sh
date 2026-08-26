# shellcheck shell=bash
# Shared default-credential warning logic used by wlanstart.sh and tests.
#
# warnings_emit_credential_warnings reads SSID and WPA_PASSPHRASE from the
# environment (already defaulted) and prints a warning for each value
# still at its insecure default.
warnings_emit_credential_warnings() {
    if [ "${SSID}" = "raspberry" ] ; then
        echo "[Warning] Using default SSID 'raspberry'. Set SSID env var for production."
    fi
    if [ "${WPA_PASSPHRASE}" = "passw0rd" ] ; then
        echo "[Warning] Using default WPA passphrase. Set WPA_PASSPHRASE env var for production."
    fi
}
