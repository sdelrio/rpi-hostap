#!/bin/bash

# General-purpose leveled logging library (issue #177).
#
# Distinct from lib/sys/logging.sh, which handles failure reporting for the
# container entrypoint. This library provides a simple log() function with
# severity levels, ANSI colors when attached to a terminal, a structured
# output format and optional routing to a log file.
#
# Usage:
#   source ./lib/sys/log.sh
#   log info "service started"
#   log fatal "unrecoverable error"   # exits non-zero
#
# Configuration (environment):
#   LOG_LEVEL  Minimum severity to emit: DEBUG, INFO, WARN, ERROR, FATAL.
#              Default: DEBUG (everything is emitted).
#   LOG_FILE   When set, all records are appended to this file instead of
#              the console (still honoring LOG_LEVEL).

# Numeric severities used for threshold comparisons.
_LOG_DEBUG=0
_LOG_INFO=1
_LOG_WARN=2
_LOG_ERROR=3
_LOG_FATAL=4

_log_level_num() {
    case "$(printf '%s' "${1}" | tr '[:lower:]' '[:upper:]')" in
        DEBUG)          echo "${_LOG_DEBUG}" ;;
        INFO)           echo "${_LOG_INFO}" ;;
        WARN|WARNING)   echo "${_LOG_WARN}" ;;
        ERROR)          echo "${_LOG_ERROR}" ;;
        FATAL|CRITICAL) echo "${_LOG_FATAL}" ;;
        *)              echo "" ;;
    esac
}

_log_threshold() {
    local num
    num=$(_log_level_num "${LOG_LEVEL:-DEBUG}")
    # Unrecognized LOG_LEVEL values fall back to "emit everything".
    [ -n "${num}" ] || num=${_LOG_DEBUG}
    printf '%s' "${num}"
}

# Colors are only emitted when the destination stream is a TTY and the
# user has not disabled them via NO_COLOR.
_log_color() {
    if [ -n "${NO_COLOR:-}" ] ; then
        return 1
    fi
    if [ -t 2 ] ; then
        return 0
    fi
    return 1
}

_log_emit() {
    local level="$1"
    local color="$2"
    shift 2

    local stamp pid_prefix script_name
    stamp=$(date '+%Y-%m-%dT%H:%M:%S%z')
    script_name=$(basename "${BASH_SOURCE[2]:-${0}}")
    pid_prefix="${script_name}/$$"
    local line="[$stamp] [${level}] [${pid_prefix}] $*"

    local out_fd=1
    case "${level}" in
        WARN|ERROR|FATAL) out_fd=2 ;;
    esac

    if _log_color ; then
        line="\033[${color}m${line}\033[0m"
    fi

    if [ -n "${LOG_FILE:-}" ] ; then
        # File output is always plain text.
        printf '%s\n' "[$stamp] [${level}] [${pid_prefix}] $*" >> "${LOG_FILE}"
    else
        printf '%b\n' "${line}" >&"${out_fd}"
    fi
}

# log <LEVEL> <message...>
#
# Emit a structured record at the given level. Messages below the LOG_LEVEL
# threshold are suppressed. FATAL/CRITICAL messages cause an exit with a
# non-zero status after being logged.
log() {
    local level="$1"
    shift

    local color=""
    case "$(printf '%s' "${level}" | tr '[:lower:]' '[:upper:]')" in
        DEBUG)          color="35" ;;
        INFO)           color="36" ;;
        WARN|WARNING)   color="33" ;;
        ERROR)          color="31" ;;
        FATAL|CRITICAL) color="31" ;;
        *) return 1 ;;
    esac

    local num threshold
    num=$(_log_level_num "${level}")
    threshold=$(_log_threshold)
    [ "${num}" -ge "${threshold}" ] || return 0

    _log_emit "$(_log_level_label "${level}")" "${color}" "$@"

    # Fatal levels terminate the caller with a non-zero status (which also
    # aborts scripts running under set -e).
    [ "${num}" -lt "${_LOG_FATAL}" ]
}

_log_level_label() {
    case "$(printf '%s' "${1}" | tr '[:lower:]' '[:upper:]')" in
        WARNING)  echo "WARN" ;;
        CRITICAL) echo "FATAL" ;;
        *)        printf '%s' "$1" | tr '[:lower:]' '[:upper:]' ;;
    esac
}

log_debug() { log debug "$@" ; }
log_info()  { log info  "$@" ; }
log_warn()  { log warn  "$@" ; }
log_error() { log error "$@" ; }
log_fatal() { log fatal "$@" ; }

# Sourcing must be safe under set -euo pipefail; make sure nothing here
# returns a failure status on load.
:
