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

normalize_yes_no() {
	case "${1:-}" in
	yes | true | 1)
		echo "yes"
		;;
	no | false | 0)
		echo "no"
		;;
	*)
		echo ""
		;;
	esac
}

trap cleanup EXIT

OPENVPN_RANDOM_SOURCE_DIR="${OPENVPN_RANDOM_SOURCE_DIR:-/data/openvpn-configs}"
OPENVPN_CONFIG_DIR="${OPENVPN_CONFIG_DIR:-/config/openvpn}"
OPENVPN_CONFIG_FILENAME="${OPENVPN_CONFIG_FILENAME:-openvpn.ovpn}"
OPENVPN_CONFIG_USE_SOURCE_FILENAME="${OPENVPN_CONFIG_USE_SOURCE_FILENAME:-no}"
OPENVPN_CONFIG_USE_SOURCE_FILENAME_NORMALIZED="$(normalize_yes_no "${OPENVPN_CONFIG_USE_SOURCE_FILENAME}")"

[[ -d "${OPENVPN_RANDOM_SOURCE_DIR}" ]] || log_crit "OPENVPN_RANDOM_SOURCE_DIR '${OPENVPN_RANDOM_SOURCE_DIR}' does not exist"
[[ -r "${OPENVPN_RANDOM_SOURCE_DIR}" ]] || log_crit "OPENVPN_RANDOM_SOURCE_DIR '${OPENVPN_RANDOM_SOURCE_DIR}' is not readable"
[[ -d "${OPENVPN_CONFIG_DIR}" ]] || log_crit "OPENVPN_CONFIG_DIR '${OPENVPN_CONFIG_DIR}' does not exist"
[[ -w "${OPENVPN_CONFIG_DIR}" ]] || log_crit "OPENVPN_CONFIG_DIR '${OPENVPN_CONFIG_DIR}' is not writable"
[[ "${OPENVPN_CONFIG_FILENAME}" == *.ovpn ]] || log_crit "OPENVPN_CONFIG_FILENAME must end with '.ovpn'"
[[ "${OPENVPN_CONFIG_FILENAME}" != */* ]] || log_crit "OPENVPN_CONFIG_FILENAME must be a filename, not a path"
[[ -n "${OPENVPN_CONFIG_USE_SOURCE_FILENAME_NORMALIZED}" ]] || log_crit "OPENVPN_CONFIG_USE_SOURCE_FILENAME must be one of: 'yes', 'no', 'true', 'false', '1', or '0'"

source_abs="$(absolute_dir "${OPENVPN_RANDOM_SOURCE_DIR}")" || log_crit "Unable to resolve OPENVPN_RANDOM_SOURCE_DIR '${OPENVPN_RANDOM_SOURCE_DIR}'"
target_abs="$(absolute_dir "${OPENVPN_CONFIG_DIR}")" || log_crit "Unable to resolve OPENVPN_CONFIG_DIR '${OPENVPN_CONFIG_DIR}'"

if [[ "${source_abs}" == "${target_abs}" ]]; then
	log_crit "Source and target directories are the same; refusing to delete configs from '${OPENVPN_CONFIG_DIR}'"
fi

configs=()
while IFS= read -r -d '' config_file; do
	configs+=("${config_file}")
done < <(find "${OPENVPN_RANDOM_SOURCE_DIR}" -maxdepth 1 -type f -name '*.ovpn' ! -name '._*.ovpn' -print0)

config_count="${#configs[@]}"
[[ "${config_count}" -gt 0 ]] || log_crit "No .ovpn files found in '${OPENVPN_RANDOM_SOURCE_DIR}'"

selected_index=$((RANDOM % config_count))
selected_config="${configs[${selected_index}]}"
if [[ "${OPENVPN_CONFIG_USE_SOURCE_FILENAME_NORMALIZED}" == "yes" ]]; then
	target_filename="$(basename "${selected_config}")"
else
	target_filename="${OPENVPN_CONFIG_FILENAME}"
fi
[[ "${target_filename}" == *.ovpn ]] || log_crit "Target OpenVPN filename must end with '.ovpn'"
[[ "${target_filename}" != */* ]] || log_crit "Target OpenVPN filename must be a filename, not a path"
target_config="${OPENVPN_CONFIG_DIR}/${target_filename}"
tmp_file="${OPENVPN_CONFIG_DIR}/.${target_filename}.tmp.$$"

[[ -r "${selected_config}" ]] || log_crit "Selected config '${selected_config}' is not readable"

log_info "Selected random OpenVPN config '${selected_config}' from ${config_count} candidate(s)"
log_info "Target OpenVPN config filename is '${target_filename}'"
cp "${selected_config}" "${tmp_file}"
chmod 600 "${tmp_file}"

log_info "Deleting existing OpenVPN configs in '${OPENVPN_CONFIG_DIR}'"
find "${OPENVPN_CONFIG_DIR}" -maxdepth 1 -type f \( -name '*.ovpn' -o -name '._*.ovpn' \) -delete

mv "${tmp_file}" "${target_config}"
tmp_file=""
chmod 600 "${target_config}"

log_info "Installed '${target_config}'"
log_info "Done"
