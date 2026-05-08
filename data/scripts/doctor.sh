#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shared_lib="${script_dir}/lib.sh"
if [[ ! -r "${shared_lib}" ]]; then
	shared_lib="/usr/local/share/nzbgetvpn/scripts/lib.sh"
fi
if [[ ! -r "${shared_lib}" ]]; then
	printf '[crit] [doctor] Shared helper library not found at %s or /usr/local/share/nzbgetvpn/scripts/lib.sh\n' "${script_dir}/lib.sh" >&2
	exit 1
fi
# shellcheck source=/dev/null
. "${shared_lib}"
NZBGETVPN_LOG_TAG="doctor"

log_info() {
	nzbgetvpn_log_info "$*"
}

log_warn() {
	nzbgetvpn_log_warn "$*" >&2
}

log_crit() {
	nzbgetvpn_log_crit "$*" >&2
}

pass_count=0
warn_count=0
fail_count=0

pass() {
	pass_count=$((pass_count + 1))
	log_info "PASS: $*"
}

warn() {
	warn_count=$((warn_count + 1))
	log_warn "WARN: $*"
}

fail() {
	fail_count=$((fail_count + 1))
	log_crit "FAIL: $*"
}

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

is_ip_address() {
	local value="$1"
	[[ "${value}" =~ ^[0-9a-fA-F:.]+$ ]]
}

check_command() {
	local cmd="$1"
	if command_exists "${cmd}"; then
		pass "Command '${cmd}' is available"
	else
		fail "Required command '${cmd}' is missing"
	fi
}

check_optional_command() {
	local cmd="$1"
	if command_exists "${cmd}"; then
		pass "Command '${cmd}' is available"
	else
		warn "Optional command '${cmd}' is missing; related checks will be skipped"
	fi
}

check_directory_rw() {
	local dir="$1"
	local label="$2"
	if [[ ! -d "${dir}" ]]; then
		fail "${label} directory '${dir}' does not exist"
		return
	fi
	if [[ ! -r "${dir}" ]]; then
		fail "${label} directory '${dir}' is not readable"
		return
	fi
	if [[ ! -w "${dir}" ]]; then
		warn "${label} directory '${dir}' is not writable"
		return
	fi
	pass "${label} directory '${dir}' is readable and writable"
}

check_nameservers() {
	local nameserver_count
	if [[ ! -r /etc/resolv.conf ]]; then
		fail "/etc/resolv.conf is not readable"
		return
	fi
	nameserver_count="$(awk '/^[[:space:]]*nameserver[[:space:]]+/ {count++} END {print count+0}' /etc/resolv.conf 2>/dev/null || echo 0)"
	if [[ "${nameserver_count}" -gt 0 ]]; then
		pass "Resolver configuration has ${nameserver_count} nameserver entry(ies)"
	else
		fail "Resolver configuration has no nameserver entries"
	fi
}

check_default_route() {
	if ! command_exists ip; then
		warn "Skipping default-route check because 'ip' command is missing"
		return
	fi
	if ip route show default | awk 'NF {found=1} END {exit(found?0:1)}'; then
		pass "Default route is present"
	else
		fail "No default route detected"
	fi
}

check_vpn_device_and_ip_signal() {
	local vpn_enabled_raw="${VPN_ENABLED:-yes}"
	local vpn_enabled
	local vpn_device="${VPN_DEVICE_TYPE:-}"
	local vpn_ip_value="${VPN_IP:-}"

	vpn_enabled="$(normalize_yes_no "${vpn_enabled_raw}")"
	if [[ -z "${vpn_enabled}" || "${vpn_enabled}" == "no" ]]; then
		return
	fi

	if [[ -z "${vpn_device}" ]]; then
		warn "VPN_DEVICE_TYPE is not set; skipping VPN interface check"
		return
	fi
	if ! command_exists ip; then
		warn "Skipping VPN interface check because 'ip' command is missing"
		return
	fi
	if ip link show "${vpn_device}" >/dev/null 2>&1; then
		pass "VPN device '${vpn_device}' exists"
	else
		fail "VPN device '${vpn_device}' is not present"
		return
	fi

	if [[ -z "${vpn_ip_value}" ]]; then
		vpn_ip_value="$(ip -4 -o addr show dev "${vpn_device}" 2>/dev/null | awk '{print $4}' | awk -F/ 'NR==1{print $1}')"
	fi
	if [[ -n "${vpn_ip_value}" ]]; then
		pass "VPN IP signal detected (${vpn_ip_value})"
	else
		warn "VPN IP signal is empty"
	fi
}

check_internet_reachability() {
	local enabled_raw="$1"
	local timeout_secs="$2"
	local url="$3"
	local enabled

	enabled="$(normalize_yes_no "${enabled_raw}")"
	if [[ "${enabled}" != "yes" ]]; then
		log_info "Internet reachability check disabled"
		return
	fi

	if curl --fail --silent --show-error --location --max-time "${timeout_secs}" --output /dev/null "${url}"; then
		pass "Internet check succeeded via ${url}"
	else
		warn "Internet check failed for ${url} within ${timeout_secs}s"
	fi
}

check_vpn_client_config() {
	local openvpn_dir="$1"
	local wireguard_dir="$2"
	local vpn_enabled_raw="${VPN_ENABLED:-yes}"
	local vpn_enabled
	local vpn_client="${VPN_CLIENT:-}"
	local ovpn_count wg_count
	local -a ovpn_files wg_files

	vpn_enabled="$(normalize_yes_no "${vpn_enabled_raw}")"
	if [[ -z "${vpn_enabled}" ]]; then
		warn "VPN_ENABLED='${vpn_enabled_raw}' is not a recognized boolean; expected yes/no/true/false/1/0"
		return
	fi
	if [[ "${vpn_enabled}" == "no" ]]; then
		warn "VPN is disabled (VPN_ENABLED=${vpn_enabled_raw}); skipping VPN profile checks"
		return
	fi

	case "${vpn_client}" in
	openvpn)
		ovpn_files=("${openvpn_dir}"/*.ovpn)
		ovpn_count=0
		if [[ -e "${ovpn_files[0]:-}" ]]; then
			ovpn_count="${#ovpn_files[@]}"
		fi
		if [[ "${ovpn_count}" -gt 0 ]]; then
			pass "OpenVPN mode with ${ovpn_count} profile(s) in ${openvpn_dir}"
		else
			fail "VPN_CLIENT=openvpn but no .ovpn profiles found in ${openvpn_dir}"
		fi
		;;
	wireguard)
		wg_files=("${wireguard_dir}"/*.conf)
		wg_count=0
		if [[ -e "${wg_files[0]:-}" ]]; then
			wg_count="${#wg_files[@]}"
		fi
		if [[ "${wg_count}" -gt 0 ]]; then
			pass "WireGuard mode with ${wg_count} profile(s) in ${wireguard_dir}"
		else
			fail "VPN_CLIENT=wireguard but no .conf profiles found in ${wireguard_dir}"
		fi
		;;
	*)
		fail "VPN_CLIENT must be set to 'openvpn' or 'wireguard' when VPN is enabled"
		;;
	esac
}

main() {
	local data_dir="${DOCTOR_DATA_DIR:-/data}"
	local config_dir="${DOCTOR_CONFIG_DIR:-/config}"
	local openvpn_dir="${DOCTOR_OPENVPN_DIR:-${config_dir}/openvpn}"
	local wireguard_dir="${DOCTOR_WIREGUARD_DIR:-${config_dir}/wireguard}"
	local internet_check_enabled_raw="${DOCTOR_INTERNET_CHECK_ENABLED:-no}"
	local internet_check_timeout="${DOCTOR_INTERNET_CHECK_TIMEOUT:-5}"
	local internet_check_url="${DOCTOR_INTERNET_CHECK_URL:-https://1.1.1.1}"
	local internet_check_enabled
	local dns_server
	local dns_entries_found=0

	log_info "Starting NZBGetVPN doctor checks"
	validate_absolute_path "${data_dir}" || fail "DOCTOR_DATA_DIR must be an absolute path without '..'"
	validate_absolute_path "${config_dir}" || fail "DOCTOR_CONFIG_DIR must be an absolute path without '..'"
	validate_absolute_path "${openvpn_dir}" || fail "DOCTOR_OPENVPN_DIR must be an absolute path without '..'"
	validate_absolute_path "${wireguard_dir}" || fail "DOCTOR_WIREGUARD_DIR must be an absolute path without '..'"
	internet_check_enabled="$(normalize_yes_no "${internet_check_enabled_raw}")"
	if [[ -z "${internet_check_enabled}" ]]; then
		fail "DOCTOR_INTERNET_CHECK_ENABLED must be yes/no/true/false/1/0"
	fi
	is_positive_integer "${internet_check_timeout}" || fail "DOCTOR_INTERNET_CHECK_TIMEOUT must be a positive integer"
	[[ "${internet_check_url}" == http://* || "${internet_check_url}" == https://* ]] || fail "DOCTOR_INTERNET_CHECK_URL must start with http:// or https://"

	check_command awk
	check_command curl
	check_optional_command ip
	check_directory_rw "${data_dir}" "Data"
	check_directory_rw "${config_dir}" "Config"
	check_default_route
	check_nameservers
	while IFS= read -r dns_server; do
		[[ -n "${dns_server}" ]] || continue
		dns_entries_found=1
		if is_ip_address "${dns_server}"; then
			pass "Resolver entry '${dns_server}' looks valid"
		else
			warn "Resolver entry '${dns_server}' is not a plain IP address"
		fi
	done <<EOF
$(awk '/^[[:space:]]*nameserver[[:space:]]+/ {print $2}' /etc/resolv.conf 2>/dev/null || true)
EOF
	if [[ "${dns_entries_found}" -eq 0 ]]; then
		warn "No resolver entries found for syntax validation"
	fi
	check_vpn_device_and_ip_signal
	check_vpn_client_config "${openvpn_dir}" "${wireguard_dir}"
	check_internet_reachability "${internet_check_enabled_raw}" "${internet_check_timeout}" "${internet_check_url}"

	log_info "Doctor summary: pass=${pass_count} warn=${warn_count} fail=${fail_count}"
	if [[ "${fail_count}" -gt 0 ]]; then
		log_crit "Doctor checks found critical issues"
		exit 1
	fi
	log_info "Doctor checks completed without critical issues"
}

main "$@"
