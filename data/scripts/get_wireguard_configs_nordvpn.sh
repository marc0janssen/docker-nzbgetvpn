#!/usr/bin/env bash

set -Eeuo pipefail

log_info() {
	printf '[info] %s\n' "$*"
}

log_crit() {
	printf '[crit] %s\n' "$*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || log_crit "Required command '$1' is not installed"
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

cleanup() {
	if [[ -n "${tmp_file:-}" && -f "${tmp_file}" ]]; then
		rm -f "${tmp_file}"
	fi
	if [[ -n "${tmp_dir:-}" && -d "${tmp_dir}" ]]; then
		rm -rf "${tmp_dir}"
	fi
}

trap cleanup EXIT

require_command curl
require_command jq

NORDVPN_ACCESS_TOKEN="${NORDVPN_ACCESS_TOKEN:-${ACCESS_TOKEN:-}}"
TOTAL_CONFIGS="${TOTAL_CONFIGS:-1}"
DNS="${DNS:-103.86.96.100}"
COUNTRY_NAME="${COUNTRY_NAME:-Netherlands}"
WIREGUARD_CONFIG_DIR="${WIREGUARD_CONFIG_DIR:-/config/wireguard}"
WIREGUARD_CONFIG_FILENAME="${WIREGUARD_CONFIG_FILENAME:-wg0.conf}"
WIREGUARD_CONFIG_USE_SOURCE_FILENAME="${WIREGUARD_CONFIG_USE_SOURCE_FILENAME:-no}"
WIREGUARD_ADDRESS="${WIREGUARD_ADDRESS:-10.5.0.2/32}"
WIREGUARD_PORT="${WIREGUARD_PORT:-51820}"
WIREGUARD_CONFIG_USE_SOURCE_FILENAME_NORMALIZED="$(normalize_yes_no "${WIREGUARD_CONFIG_USE_SOURCE_FILENAME}")"

[[ -n "${NORDVPN_ACCESS_TOKEN}" ]] || log_crit "Set NORDVPN_ACCESS_TOKEN before running this script"
[[ "${TOTAL_CONFIGS}" =~ ^[0-9]+$ && "${TOTAL_CONFIGS}" -gt 0 ]] || log_crit "TOTAL_CONFIGS must be a positive integer"
[[ "${WIREGUARD_PORT}" =~ ^[0-9]+$ && "${WIREGUARD_PORT}" -ge 1 && "${WIREGUARD_PORT}" -le 65535 ]] || log_crit "WIREGUARD_PORT must be a valid TCP/UDP port"
[[ -d "${WIREGUARD_CONFIG_DIR}" ]] || log_crit "WireGuard config directory '${WIREGUARD_CONFIG_DIR}' does not exist"
[[ -w "${WIREGUARD_CONFIG_DIR}" ]] || log_crit "WireGuard config directory '${WIREGUARD_CONFIG_DIR}' is not writable"
[[ "${WIREGUARD_CONFIG_FILENAME}" == *.conf ]] || log_crit "WIREGUARD_CONFIG_FILENAME must end with '.conf'"
[[ "${WIREGUARD_CONFIG_FILENAME}" != */* ]] || log_crit "WIREGUARD_CONFIG_FILENAME must be a filename, not a path"
[[ -n "${WIREGUARD_CONFIG_USE_SOURCE_FILENAME_NORMALIZED}" ]] || log_crit "WIREGUARD_CONFIG_USE_SOURCE_FILENAME must be one of: 'yes', 'no', 'true', 'false', '1', or '0'"

COUNTRIES_URL="https://api.nordvpn.com/v1/servers/countries"
CREDENTIALS_URL="https://api.nordvpn.com/v1/users/services/credentials"

log_info "Looking up NordVPN country id for '${COUNTRY_NAME}'"
country_id="$(
	curl --fail --silent --show-error --location "${COUNTRIES_URL}" |
		jq -er --arg country_name "${COUNTRY_NAME}" '[.[] | select(.name == $country_name) | .id][0] // empty'
)"

[[ -n "${country_id}" ]] || log_crit "Unable to find NordVPN country '${COUNTRY_NAME}'"

SERVER_RECOMMENDATIONS_URL="https://api.nordvpn.com/v1/servers/recommendations?filters[country_id]=${country_id}&filters[servers_technologies][identifier]=wireguard_udp&limit=${TOTAL_CONFIGS}"

log_info "Fetching NordLynx credentials"
private_key="$(
	curl --fail --silent --show-error --location \
		--user "token:${NORDVPN_ACCESS_TOKEN}" \
		"${CREDENTIALS_URL}" |
		jq -er '.nordlynx_private_key'
)"

[[ -n "${private_key}" && "${private_key}" != "null" ]] || log_crit "NordVPN did not return a NordLynx private key"

tmp_dir="$(mktemp -d)"
recommendations_json="${tmp_dir}/recommendations.json"

log_info "Fetching ${TOTAL_CONFIGS} recommended WireGuard server(s) for '${COUNTRY_NAME}'"
curl --fail --silent --show-error --location \
	--globoff \
	"${SERVER_RECOMMENDATIONS_URL}" \
	-o "${recommendations_json}"

server_count="$(jq 'length' "${recommendations_json}")"
[[ "${server_count}" =~ ^[0-9]+$ && "${server_count}" -gt 0 ]] || log_crit "NordVPN returned no WireGuard servers for '${COUNTRY_NAME}'"

while IFS=$'\t' read -r filename endpoint public_key; do
	[[ -n "${filename}" ]] || log_crit "NordVPN returned a server without a filename"
	[[ -n "${endpoint}" && "${endpoint}" != "null" ]] || log_crit "NordVPN returned server '${filename}' without endpoint"
	[[ -n "${public_key}" && "${public_key}" != "null" ]] || log_crit "NordVPN returned server '${filename}' without WireGuard public key"

	safe_filename="${filename//\//-}"
	output_file="${tmp_dir}/${safe_filename}"

	cat >"${output_file}" <<EOF
# ${safe_filename}

[Interface]
PrivateKey = ${private_key}
Address = ${WIREGUARD_ADDRESS}
DNS = ${DNS}

[Peer]
PublicKey = ${public_key}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${endpoint}:${WIREGUARD_PORT}
EOF

	chmod 600 "${output_file}"
	log_info "Prepared '${safe_filename}'"
done < <(
	jq -er '
		.[] |
		{
			filename: ((.locations[0].country.name // "Unknown") + " - " + (.locations[0].country.city.name // "Unknown") + " - " + .hostname + ".conf"),
			endpoint: .station,
			public_key: ([.technologies[] | select(.identifier == "wireguard_udp") | .metadata[] | .value][0] // empty)
		} |
		[.filename, .endpoint, .public_key] | @tsv
	' "${recommendations_json}"
)

generated_count="$(find "${tmp_dir}" -maxdepth 1 -type f -name '*.conf' | wc -l | tr -d ' ')"
[[ "${generated_count}" -gt 0 ]] || log_crit "No WireGuard config files were generated"

generated_configs=()
while IFS= read -r -d '' generated_file; do
	generated_configs+=("${generated_file}")
done < <(find "${tmp_dir}" -maxdepth 1 -type f -name '*.conf' -print0)

selected_index=$((RANDOM % generated_count))
selected_config="${generated_configs[${selected_index}]}"
if [[ "${WIREGUARD_CONFIG_USE_SOURCE_FILENAME_NORMALIZED}" == "yes" ]]; then
	target_filename="$(basename "${selected_config}")"
else
	target_filename="${WIREGUARD_CONFIG_FILENAME}"
fi
[[ "${target_filename}" == *.conf ]] || log_crit "Target WireGuard filename must end with '.conf'"
[[ "${target_filename}" != */* ]] || log_crit "Target WireGuard filename must be a filename, not a path"
target_config="${WIREGUARD_CONFIG_DIR}/${target_filename}"
tmp_file="${WIREGUARD_CONFIG_DIR}/.${target_filename}.tmp.$$"

log_info "Selected WireGuard config '${selected_config}' from ${generated_count} generated candidate(s)"
log_info "Target WireGuard config filename is '${target_filename}'"
cp "${selected_config}" "${tmp_file}"
chmod 600 "${tmp_file}"

log_info "Replacing existing WireGuard configs in '${WIREGUARD_CONFIG_DIR}'"
find "${WIREGUARD_CONFIG_DIR}" -maxdepth 1 -type f -name '*.conf' -delete

mv "${tmp_file}" "${target_config}"
tmp_file=""
chmod 600 "${target_config}"

log_info "Installed '${target_config}'"
log_info "Done"
