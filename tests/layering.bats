#!/usr/bin/env bats
# Layering rule enforcement for issue #240.
#
# lib/core/ modules must be pure: no external system commands, no writes
# outside the process. All system interaction lives in lib/sys/.

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
}

# Forbidden patterns in lib/core/: system/network commands and /proc access.
# Note the word-boundary on "ip" so it does not match variables like
# DHCP_PREFIX or comments mentioning "ipv4".
FORBIDDEN='(^|[^[:alnum:]_/-])(iptables|ip6tables|iw|sysctl|hostapd_cli|dnsmasq|ifconfig|tc|nft|head|tail|cat|tr|wc|grep|sed|awk|sort|uniq|cut|find|xargs|cp|mv|rm|chmod|chown|mkdir|stat|touch|date|basename)([^[:alnum:]_-]|$)|/proc/'
# Safe bash builtins (not blocked): echo, printf, read, true, false, return, test/[, command -v

@test "lib/core exists with at least one module" {
    [ -d "$ROOT/lib/core" ]
    first=$(find "$ROOT/lib/core" -name '*.sh' | head -n 1)
    [ -n "$first" ]
}

@test "lib/sys exists with at least one module" {
    [ -d "$ROOT/lib/sys" ]
    first=$(find "$ROOT/lib/sys" -name '*.sh' | head -n 1)
    [ -n "$first" ]
}

@test "no core module invokes forbidden system commands or /proc" {
    while IFS= read -r f; do
        if grep -Eq "${FORBIDDEN}" "$f"; then
            echo "Forbidden command/path found in ${f}:" >&2
            grep -En "${FORBIDDEN}" "$f" >&2
            return 1
        fi
    done < <(find "$ROOT/lib/core" -name '*.sh')
}

@test "no core module sources a sys module" {
    while IFS= read -r f; do
        if grep -Eq 'source.*lib/sys|^\.[[:space:]].*lib/sys' "$f"; then
            echo "core module ${f} sources a sys module" >&2
            return 1
        fi
    done < <(find "$ROOT/lib/core" -name '*.sh')
}
