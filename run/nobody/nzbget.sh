#!/usr/bin/env bash

set -euo pipefail

readonly CONFIG_DIR="/usr/sbin/nzbget_bin"
readonly CONFIG_FILE="/config/nzbget.conf"
readonly NZBGET_PORT=6789

log() {
    local level="$1"
    shift
    printf '[%s] %s\n' "$level" "$*"
}

ensure_config_file() {
    if [[ ! -f ${CONFIG_FILE} ]]; then
        log info "Nzbget config file doesn't exist, copying default"
        cp "${CONFIG_DIR}/nzbget.conf" "${CONFIG_FILE}"
    else
        log info 'Nzbget config file already exists, skipping copy'
    fi
}

set_config_value() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "${CONFIG_FILE}"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${CONFIG_FILE}"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${CONFIG_FILE}"
    fi
}

normalize_config() {
    set_config_value 'MainDir' '/data'
    set_config_value 'WebDir' '${AppDir}/webui'
    set_config_value 'ConfigTemplate' '${AppDir}/webui/nzbget.conf.template'
    set_config_value 'CertStore' '/usr/sbin/nzbget_bin/cacert.pem'
}

wait_for_process() {
    local process_name="$1"
    local retries=12
    local wait_seconds=1

    while ! pgrep -x "${process_name}" >/dev/null; do
        ((retries--)) || {
            log warn "Wait for ${process_name} process to start aborted, too many retries"
            return 1
        }

        if [[ ${DEBUG:-false} == true ]]; then
            log debug "Waiting for ${process_name} process to start"
            log debug "Re-check in ${wait_seconds} secs"
            log debug "${retries} retries left"
        fi
        sleep "${wait_seconds}"
    done

    log info "${process_name^} process started"
}

wait_for_port() {
    local port="$1"
    log info "Waiting for Nzbget process to start listening on port ${port}"
    while true; do
        if command -v ss >/dev/null; then
            if ss -ltn | awk '{print $4}' | grep -q ":${port}$"; then
                break
            fi
        else
            if netstat -ltn | awk '$6 == "LISTEN" && $4 ~ "\.${port}$"' | grep -q ':'; then
                break
            fi
        fi
        sleep 0.1
    done
    log info "Nzbget process is listening on port ${port}"
}

start_nzbget() {
    log info 'Attempting to start nzbget'
    /usr/bin/nzbget -D -c "${CONFIG_FILE}"
    wait_for_process nzbget || true
    wait_for_port "${NZBGET_PORT}"
}

main() {
    ensure_config_file
    normalize_config

    if [[ ${nzbget_running:-false} == false ]]; then
        start_nzbget
    fi

    nzbget_ip="${vpn_ip:-}" # shellcheck disable=SC2034
}

main "$@"
