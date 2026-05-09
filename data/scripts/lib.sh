#!/usr/bin/env bash

is_enabled() {
	case "${1:-}" in
	yes | true | 1)
		return 0
		;;
	*)
		return 1
		;;
	esac
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

is_positive_integer() {
	[[ "${1:-}" =~ ^[0-9]+$ ]] && [[ "${1}" -gt 0 ]]
}

trim() {
	printf '%s' "${1:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

validate_absolute_path() {
	local value="${1:-}"

	[[ -n "${value}" ]] || return 1
	[[ "${value}" == /* ]] || return 1
	[[ "${value}" != *..* ]] || return 1
}

nzbgetvpn_log_emit() {
	local level="$1"
	local message="$2"
	local tag="${NZBGETVPN_LOG_TAG:-}"
	if [[ -n "${tag}" ]]; then
		printf '[%s] [%s] %s\n' "${level}" "${tag}" "${message}"
	else
		printf '[%s] %s\n' "${level}" "${message}"
	fi
}

nzbgetvpn_log_info() {
	nzbgetvpn_log_emit "info" "$*"
}

nzbgetvpn_log_warn() {
	nzbgetvpn_log_emit "warn" "$*"
}

nzbgetvpn_log_crit() {
	nzbgetvpn_log_emit "crit" "$*"
}

nzbgetvpn_get_default() {
	case "${1:-}" in
	ROTATE_MODE) echo "auto" ;;
	ROTATE_SPEEDTEST_URLS) echo "https://freetestdata.com/wp-content/uploads/2021/09/Free_Test_Data_1OMB_MP3.mp3,https://proof.ovh.net/files/10Mb.dat" ;;
	ROTATE_SPEEDTEST_WEIGHTS) echo "0.60,0.40" ;;
	ROTATE_SPEEDTEST_TIMEOUT) echo "20" ;;
	ROTATE_SPEEDTEST_ATTEMPTS) echo "1" ;;
	ROTATE_MIN_SUCCESSFUL_ENDPOINTS) echo "1" ;;
	ROTATE_MIN_DOWNLOAD_MBPS) echo "10" ;;
	ROTATE_MAX_LATENCY_MS) echo "700" ;;
	ROTATE_FAIL_STREAK) echo "3" ;;
	ROTATE_COOLDOWN_SECONDS) echo "1800" ;;
	ROTATE_STATE_FILE) echo "/data/rotate-on-poor-speed-state" ;;
	ROTATE_WIREGUARD_SCRIPT) echo "/data/scripts/container/select_random_wireguard_config.sh" ;;
	ROTATE_OPENVPN_SCRIPT) echo "/data/scripts/container/select_random_openvpn_config.sh" ;;
	ROTATE_WIREGUARD_REFRESH_SCRIPT) echo "/data/scripts/container/get_wireguard_configs_nordvpn.sh" ;;
	ROTATE_WIREGUARD_REFRESH_ENABLED) echo "no" ;;
	ROTATE_POST_ROTATION_ACTION) echo "none" ;;
	ROTATE_RESTART_REQUEST_FILE) echo "/tmp/rotate-on-poor-speed-exit-watchdog" ;;
	ROTATE_ON_POOR_SPEED_ENABLED) echo "yes" ;;
	ROTATE_ON_POOR_SPEED_SCHEDULE) echo "*/20 * * * *" ;;
	ROTATE_ON_POOR_SPEED_SCRIPT) echo "/data/scripts/container/rotate_on_poor_speed.sh" ;;
	ROTATE_ON_POOR_SPEED_TIMEOUT) echo "90" ;;
	ROTATE_RESTART_EXIT_DELAY) echo "5" ;;
	*) return 1 ;;
	esac
}

nzbgetvpn_print_rotate_defaults() {
	local key value
	for key in \
		ROTATE_MODE \
		ROTATE_SPEEDTEST_URLS \
		ROTATE_SPEEDTEST_WEIGHTS \
		ROTATE_SPEEDTEST_TIMEOUT \
		ROTATE_SPEEDTEST_ATTEMPTS \
		ROTATE_MIN_SUCCESSFUL_ENDPOINTS \
		ROTATE_MIN_DOWNLOAD_MBPS \
		ROTATE_MAX_LATENCY_MS \
		ROTATE_FAIL_STREAK \
		ROTATE_COOLDOWN_SECONDS \
		ROTATE_POST_ROTATION_ACTION \
		ROTATE_ON_POOR_SPEED_ENABLED \
		ROTATE_ON_POOR_SPEED_SCHEDULE \
		ROTATE_ON_POOR_SPEED_SCRIPT \
		ROTATE_ON_POOR_SPEED_TIMEOUT; do
		value="$(nzbgetvpn_get_default "${key}")" || continue
		printf '%s=%s\n' "${key}" "${value}"
	done
}
