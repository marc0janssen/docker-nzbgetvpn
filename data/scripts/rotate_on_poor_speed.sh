#!/usr/bin/env bash
set -Eeuo pipefail

log_info() {
	printf '[info] [rotate-on-poor-speed] %s\n' "$*"
}

log_warn() {
	printf '[warn] [rotate-on-poor-speed] %s\n' "$*" >&2
}

log_crit() {
	printf '[crit] [rotate-on-poor-speed] %s\n' "$*" >&2
	exit 1
}

normalize_yes_no() {
	case "${1:-}" in
		yes|true|1) echo "yes" ;;
		no|false|0) echo "no" ;;
		*) echo "" ;;
	esac
}

is_positive_integer() {
	[[ "${1:-}" =~ ^[0-9]+$ ]] && [[ "${1}" -gt 0 ]]
}

validate_absolute_path() {
	local value="$1"
	local name="$2"

	[[ -n "${value}" ]] || log_crit "${name} is empty"
	[[ "${value}" == /* ]] || log_crit "${name} must be an absolute path"
	[[ "${value}" != *..* ]] || log_crit "${name} must not contain '..'"
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || log_crit "Required command '$1' is not installed"
}

read_state() {
	local state_file="$1"
	local key="$2"

	if [[ ! -f "${state_file}" ]]; then
		return 1
	fi
	awk -F= -v key="${key}" '$1==key {print substr($0, index($0, "=")+1); exit}' "${state_file}" 2>/dev/null
}

write_state() {
	local state_file="$1"
	local fail_streak="$2"
	local last_rotate_epoch="$3"
	local last_reason="$4"
	local last_mode="$5"
	local dir tmp

	dir="$(dirname -- "${state_file}")"
	[[ -d "${dir}" ]] || mkdir -p -- "${dir}"
	[[ -w "${dir}" ]] || log_crit "State directory '${dir}' is not writable"

	tmp="$(mktemp "${dir}/.rotate-on-poor-speed.XXXXXX")"
	trap 'rm -f -- "${tmp}"' EXIT
	cat > "${tmp}" <<EOF
fail_streak=${fail_streak}
last_rotate_epoch=${last_rotate_epoch}
last_reason=${last_reason}
last_mode=${last_mode}
EOF
	chmod 600 "${tmp}" || true
	mv -f -- "${tmp}" "${state_file}"
	trap - EXIT
}

run_speed_test() {
	local url="$1"
	local timeout_secs="$2"
	local curl_result
	local speed_bps
	local ttfb_secs
	local speed_mbps latency_ms

	curl_result="$(curl --fail --silent --show-error --location --max-time "${timeout_secs}" \
		--output /dev/null --write-out '%{speed_download} %{time_starttransfer}' "${url}")" || return 1

	speed_bps="$(printf '%s' "${curl_result}" | awk '{print $1}')"
	ttfb_secs="$(printf '%s' "${curl_result}" | awk '{print $2}')"
	[[ -n "${speed_bps}" && -n "${ttfb_secs}" ]] || return 1

	speed_mbps="$(awk -v bps="${speed_bps}" 'BEGIN {printf "%.2f", (bps*8)/1000000}')"
	latency_ms="$(awk -v secs="${ttfb_secs}" 'BEGIN {printf "%.0f", secs*1000}')"
	printf '%s %s\n' "${speed_mbps}" "${latency_ms}"
}

execute_rotation() {
	local mode="$1"
	local rotate_wg_script="$2"
	local rotate_ovpn_script="$3"
	local refresh_enabled="$4"
	local refresh_script="$5"
	local reason="$6"

	log_warn "Rotation triggered (${reason}) using mode '${mode}'"

	case "${mode}" in
		wireguard)
			if [[ "${refresh_enabled}" == "yes" ]]; then
				[[ -x "${refresh_script}" ]] || log_crit "ROTATE_WIREGUARD_REFRESH_SCRIPT '${refresh_script}' is not executable"
				log_info "Refreshing WireGuard profiles before rotation"
				"${refresh_script}"
			fi
			[[ -x "${rotate_wg_script}" ]] || log_crit "ROTATE_WIREGUARD_SCRIPT '${rotate_wg_script}' is not executable"
			"${rotate_wg_script}"
			;;
		openvpn)
			[[ -x "${rotate_ovpn_script}" ]] || log_crit "ROTATE_OPENVPN_SCRIPT '${rotate_ovpn_script}' is not executable"
			"${rotate_ovpn_script}"
			;;
		*)
			log_crit "Internal error: unsupported rotation mode '${mode}'"
			;;
	esac
}

main() {
	local mode="${ROTATE_MODE:-auto}"
	local speedtest_url="${ROTATE_SPEEDTEST_URL:-https://speed.cloudflare.com/__down?bytes=4000000}"
	local timeout_secs="${ROTATE_SPEEDTEST_TIMEOUT:-20}"
	local min_mbps="${ROTATE_MIN_DOWNLOAD_MBPS:-10}"
	local max_latency_ms="${ROTATE_MAX_LATENCY_MS:-700}"
	local fail_streak_required="${ROTATE_FAIL_STREAK:-3}"
	local cooldown_seconds="${ROTATE_COOLDOWN_SECONDS:-1800}"
	local state_file="${ROTATE_STATE_FILE:-/data/rotate-on-poor-speed-state}"
	local wg_script="${ROTATE_WIREGUARD_SCRIPT:-/data/scripts/select_random_wireguard_config.sh}"
	local ovpn_script="${ROTATE_OPENVPN_SCRIPT:-/data/scripts/select_random_openvpn_config.sh}"
	local refresh_script="${ROTATE_WIREGUARD_REFRESH_SCRIPT:-/data/scripts/get_wireguard_configs_nordvpn.sh}"
	local refresh_enabled
	local post_action="${ROTATE_POST_ROTATION_ACTION:-none}"
	local restart_request_file="${ROTATE_RESTART_REQUEST_FILE:-/tmp/rotate-on-poor-speed-exit-watchdog}"
	local now current_streak previous_streak last_rotate_epoch
	local speed_mbps latency_ms poor_reason=""
	local selected_mode

	require_command curl
	validate_absolute_path "${state_file}" "ROTATE_STATE_FILE"
	validate_absolute_path "${wg_script}" "ROTATE_WIREGUARD_SCRIPT"
	validate_absolute_path "${ovpn_script}" "ROTATE_OPENVPN_SCRIPT"
	validate_absolute_path "${refresh_script}" "ROTATE_WIREGUARD_REFRESH_SCRIPT"

	is_positive_integer "${timeout_secs}" || log_crit "ROTATE_SPEEDTEST_TIMEOUT must be a positive integer"
	is_positive_integer "${fail_streak_required}" || log_crit "ROTATE_FAIL_STREAK must be a positive integer"
	is_positive_integer "${cooldown_seconds}" || log_crit "ROTATE_COOLDOWN_SECONDS must be a positive integer"
	[[ "${min_mbps}" =~ ^[0-9]+([.][0-9]+)?$ ]] || log_crit "ROTATE_MIN_DOWNLOAD_MBPS must be numeric"
	[[ "${max_latency_ms}" =~ ^[0-9]+$ ]] || log_crit "ROTATE_MAX_LATENCY_MS must be an integer"

	refresh_enabled="$(normalize_yes_no "${ROTATE_WIREGUARD_REFRESH_ENABLED:-no}")"
	[[ -n "${refresh_enabled}" ]] || log_crit "ROTATE_WIREGUARD_REFRESH_ENABLED must be yes/no/true/false/1/0"
	case "${post_action}" in
		none|watchdog-exit)
			;;
		*)
			log_crit "ROTATE_POST_ROTATION_ACTION must be 'none' or 'watchdog-exit'"
			;;
	esac
	validate_absolute_path "${restart_request_file}" "ROTATE_RESTART_REQUEST_FILE"

	case "${mode}" in
		auto)
			case "${VPN_CLIENT:-}" in
				wireguard) selected_mode="wireguard" ;;
				openvpn) selected_mode="openvpn" ;;
				*) log_crit "ROTATE_MODE=auto requires VPN_CLIENT=openvpn or VPN_CLIENT=wireguard" ;;
			esac
			;;
		wireguard|openvpn)
			selected_mode="${mode}"
			;;
		*)
			log_crit "ROTATE_MODE must be 'auto', 'wireguard', or 'openvpn'"
			;;
	esac

	if ! read -r speed_mbps latency_ms < <(run_speed_test "${speedtest_url}" "${timeout_secs}"); then
		log_warn "Speed test failed for '${speedtest_url}'"
		poor_reason="speedtest_failed"
		speed_mbps="0"
		latency_ms="${max_latency_ms}"
	fi

	log_info "Measured speed=${speed_mbps}Mbps latency=${latency_ms}ms (thresholds: min=${min_mbps}Mbps max=${max_latency_ms}ms)"

	if [[ -z "${poor_reason}" ]]; then
		if awk -v measured="${speed_mbps}" -v min="${min_mbps}" 'BEGIN {exit (measured < min) ? 0 : 1}'; then
			poor_reason="low_speed"
		elif [[ "${latency_ms}" -gt "${max_latency_ms}" ]]; then
			poor_reason="high_latency"
		fi
	fi

	previous_streak="$(read_state "${state_file}" fail_streak || true)"
	last_rotate_epoch="$(read_state "${state_file}" last_rotate_epoch || true)"
	[[ "${previous_streak}" =~ ^[0-9]+$ ]] || previous_streak=0
	[[ "${last_rotate_epoch}" =~ ^[0-9]+$ ]] || last_rotate_epoch=0

	if [[ -n "${poor_reason}" ]]; then
		current_streak=$((previous_streak + 1))
	else
		current_streak=0
	fi

	now="$(date +%s)"
	write_state "${state_file}" "${current_streak}" "${last_rotate_epoch}" "${poor_reason:-ok}" "${selected_mode}"

	if [[ -z "${poor_reason}" ]]; then
		log_info "Connection quality is acceptable; no rotation needed"
		exit 0
	fi

	log_warn "Poor connection detected (${poor_reason}), streak=${current_streak}/${fail_streak_required}"
	if [[ "${current_streak}" -lt "${fail_streak_required}" ]]; then
		exit 0
	fi

	if [[ "${last_rotate_epoch}" -gt 0 ]] && [[ $((now - last_rotate_epoch)) -lt "${cooldown_seconds}" ]]; then
		log_warn "Rotation suppressed by cooldown (${now-last_rotate_epoch}s/${cooldown_seconds}s)"
		exit 0
	fi

	execute_rotation "${selected_mode}" "${wg_script}" "${ovpn_script}" "${refresh_enabled}" "${refresh_script}" "${poor_reason}"
	write_state "${state_file}" 0 "${now}" "${poor_reason}" "${selected_mode}"
	log_info "Rotation completed (${selected_mode})"

	if [[ "${post_action}" == "watchdog-exit" ]]; then
		printf 'rotate_on_poor_speed %s %s\n' "${selected_mode}" "${now}" > "${restart_request_file}" || \
			log_crit "Failed to write restart request file '${restart_request_file}'"
		log_warn "Requested watchdog exit via '${restart_request_file}' to force container restart"
	fi
}

main "$@"
