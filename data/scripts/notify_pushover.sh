#!/usr/bin/env bash

set -Eeuo pipefail

log_info() {
	printf '[info] %s\n' "$*"
}

log_crit() {
	printf '[crit] %s\n' "$*" >&2
	exit 1
}

build_message() {
	if [[ -n "${NOTIFY_MESSAGE:-}" ]]; then
		echo "${NOTIFY_MESSAGE}"
		return 0
	fi

	local previous_state="${VPN_SELFTEST_PREVIOUS_STATE:-unknown}"
	local current_state="${VPN_SELFTEST_CURRENT_STATE:-unknown}"
	local warn_count="${VPN_SELFTEST_WARN_COUNT:-0}"
	local fail_count="${VPN_SELFTEST_FAIL_COUNT:-0}"
	local host_name

	host_name="$(hostname 2>/dev/null || echo nzbgetvpn)"
	echo "NZBGetVPN (${host_name}) state change: ${previous_state} -> ${current_state} (warn=${warn_count}, fail=${fail_count})"
}

main() {
	local app_token="${PUSHOVER_APP_TOKEN:-}"
	local user_key="${PUSHOVER_USER_KEY:-}"
	local title="${PUSHOVER_TITLE:-NZBGetVPN}"
	local priority="${PUSHOVER_PRIORITY:-0}"
	local device="${PUSHOVER_DEVICE:-}"
	local sound="${PUSHOVER_SOUND:-}"
	local message

	if [[ -z "${app_token}" ]]; then
		log_crit "PUSHOVER_APP_TOKEN is required"
	fi
	if [[ -z "${user_key}" ]]; then
		log_crit "PUSHOVER_USER_KEY is required"
	fi
	if ! command -v curl >/dev/null 2>&1; then
		log_crit "curl is required"
	fi
	if ! [[ "${priority}" =~ ^-?[0-2]$ ]]; then
		log_crit "PUSHOVER_PRIORITY must be between -2 and 2"
	fi

	message="$(build_message)"

	if ! curl -fsS --max-time 15 -X POST "https://api.pushover.net/1/messages.json" \
		--data-urlencode "token=${app_token}" \
		--data-urlencode "user=${user_key}" \
		--data-urlencode "title=${title}" \
		--data-urlencode "message=${message}" \
		--data-urlencode "priority=${priority}" \
		${device:+--data-urlencode "device=${device}"} \
		${sound:+--data-urlencode "sound=${sound}"} \
		>/dev/null; then
		log_crit "Failed to send Pushover notification"
	fi

	log_info "Pushover notification sent"
}

main "$@"
