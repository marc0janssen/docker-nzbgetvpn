#!/usr/bin/env bash

set -Eeuo pipefail

log_info() {
	printf '[info] %s\n' "$*"
}

log_crit() {
	printf '[crit] %s\n' "$*" >&2
	exit 1
}

cleanup() {
	if [[ -n "${tmp_file:-}" && -f "${tmp_file}" ]]; then
		rm -f "${tmp_file}"
	fi
}

absolute_dir() {
	local dir="$1"

	[[ -d "${dir}" ]] || return 1
	(
		cd -P -- "${dir}" >/dev/null 2>&1
		pwd -P
	)
}

trap cleanup EXIT

WIREGUARD_RANDOM_SOURCE_DIR="${WIREGUARD_RANDOM_SOURCE_DIR:-/data/wireguard-configs}"
WIREGUARD_CONFIG_DIR="${WIREGUARD_CONFIG_DIR:-/config/wireguard}"
WIREGUARD_CONFIG_FILENAME="${WIREGUARD_CONFIG_FILENAME:-wg0.conf}"
WIREGUARD_CONFIG_USE_SOURCE_FILENAME="${WIREGUARD_CONFIG_USE_SOURCE_FILENAME:-no}"

[[ -d "${WIREGUARD_RANDOM_SOURCE_DIR}" ]] || log_crit "WIREGUARD_RANDOM_SOURCE_DIR '${WIREGUARD_RANDOM_SOURCE_DIR}' does not exist"
[[ -r "${WIREGUARD_RANDOM_SOURCE_DIR}" ]] || log_crit "WIREGUARD_RANDOM_SOURCE_DIR '${WIREGUARD_RANDOM_SOURCE_DIR}' is not readable"
[[ -d "${WIREGUARD_CONFIG_DIR}" ]] || log_crit "WIREGUARD_CONFIG_DIR '${WIREGUARD_CONFIG_DIR}' does not exist"
[[ -w "${WIREGUARD_CONFIG_DIR}" ]] || log_crit "WIREGUARD_CONFIG_DIR '${WIREGUARD_CONFIG_DIR}' is not writable"
[[ "${WIREGUARD_CONFIG_FILENAME}" == *.conf ]] || log_crit "WIREGUARD_CONFIG_FILENAME must end with '.conf'"
[[ "${WIREGUARD_CONFIG_FILENAME}" != */* ]] || log_crit "WIREGUARD_CONFIG_FILENAME must be a filename, not a path"
[[ "${WIREGUARD_CONFIG_USE_SOURCE_FILENAME}" == "yes" || "${WIREGUARD_CONFIG_USE_SOURCE_FILENAME}" == "no" ]] || log_crit "WIREGUARD_CONFIG_USE_SOURCE_FILENAME must be 'yes' or 'no'"

source_abs="$(absolute_dir "${WIREGUARD_RANDOM_SOURCE_DIR}")" || log_crit "Unable to resolve WIREGUARD_RANDOM_SOURCE_DIR '${WIREGUARD_RANDOM_SOURCE_DIR}'"
target_abs="$(absolute_dir "${WIREGUARD_CONFIG_DIR}")" || log_crit "Unable to resolve WIREGUARD_CONFIG_DIR '${WIREGUARD_CONFIG_DIR}'"

if [[ "${source_abs}" == "${target_abs}" ]]; then
	log_crit "Source and target directories are the same; refusing to delete configs from '${WIREGUARD_CONFIG_DIR}'"
fi

configs=()
while IFS= read -r -d '' config_file; do
	configs+=("${config_file}")
done < <(find "${WIREGUARD_RANDOM_SOURCE_DIR}" -maxdepth 1 -type f -name '*.conf' -print0)

config_count="${#configs[@]}"
[[ "${config_count}" -gt 0 ]] || log_crit "No .conf files found in '${WIREGUARD_RANDOM_SOURCE_DIR}'"

selected_index=$((RANDOM % config_count))
selected_config="${configs[${selected_index}]}"
if [[ "${WIREGUARD_CONFIG_USE_SOURCE_FILENAME}" == "yes" ]]; then
	target_filename="$(basename "${selected_config}")"
else
	target_filename="${WIREGUARD_CONFIG_FILENAME}"
fi
[[ "${target_filename}" == *.conf ]] || log_crit "Target WireGuard filename must end with '.conf'"
[[ "${target_filename}" != */* ]] || log_crit "Target WireGuard filename must be a filename, not a path"
target_config="${WIREGUARD_CONFIG_DIR}/${target_filename}"
tmp_file="${WIREGUARD_CONFIG_DIR}/.${target_filename}.tmp.$$"

[[ -r "${selected_config}" ]] || log_crit "Selected config '${selected_config}' is not readable"

log_info "Selected random WireGuard config '${selected_config}' from ${config_count} candidate(s)"
log_info "Target WireGuard config filename is '${target_filename}'"
cp "${selected_config}" "${tmp_file}"
chmod 600 "${tmp_file}"

log_info "Deleting existing WireGuard configs in '${WIREGUARD_CONFIG_DIR}'"
find "${WIREGUARD_CONFIG_DIR}" -maxdepth 1 -type f -name '*.conf' -delete

mv "${tmp_file}" "${target_config}"
tmp_file=""
chmod 600 "${target_config}"

log_info "Installed '${target_config}'"
log_info "Done"
