#!/usr/bin/env bash

set -euo pipefail

log() {
    local level="$1"
    shift
    printf '[%s] %s\n' "$level" "$*"
}

start_if_not_running() {
    local description="$1"
    local process_name="$2"
    local start_script="$3"

    if pgrep -x "$process_name" >/dev/null; then
        return
    fi

    log info "${description} not running"
    # shellcheck disable=SC1090
    if ! source "$start_script"; then
        log warn "Failed to start ${description} via ${start_script}"
    fi
}

run_vpn_checks() {
    # shellcheck disable=SC1091
    if ! source /home/nobody/preruncheck.sh; then
        log warn 'Failed to execute preruncheck.sh'
        return
    fi

    if [[ -z ${vpn_ip:-} ]]; then
        log warn 'VPN IP not detected, VPN tunnel maybe down'
        return
    fi

    start_if_not_running 'nzbget' 'nzbget' /home/nobody/nzbget.sh

    if [[ ${ENABLE_PRIVOXY:-no} == yes ]]; then
        start_if_not_running 'Privoxy' 'privoxy' /home/nobody/privoxy.sh
    fi
}

run_non_vpn_checks() {
    start_if_not_running 'Nzbget' 'nzbget' /home/nobody/nzbget.sh

    if [[ ${ENABLE_PRIVOXY:-no} == yes ]]; then
        start_if_not_running 'Privoxy' 'privoxy' /home/nobody/privoxy.sh
    fi
}

main() {
    while :; do
        if [[ ${VPN_ENABLED:-no} == yes ]]; then
            run_vpn_checks
        else
            run_non_vpn_checks
        fi

        if [[ ${DEBUG:-false} == true && ${VPN_ENABLED:-no} == yes ]]; then
            log debug "VPN IP is ${vpn_ip:-unknown}"
        fi

        sleep 30
    done
}

main "$@"
