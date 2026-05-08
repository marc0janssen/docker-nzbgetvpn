#!/usr/bin/env bash

set -Eeuo pipefail

log_info() {
	printf '[info] %s\n' "$*"
}

log_crit() {
	printf '[crit] %s\n' "$*" >&2
	exit 1
}

json_escape() {
	echo -n "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
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
	local webhook_url="${DISCORD_WEBHOOK_URL:-}"
	local username="${DISCORD_USERNAME:-NZBGetVPN}"
	local avatar_url="${DISCORD_AVATAR_URL:-}"
	local mentions="${DISCORD_MENTIONS:-}"
	local message
	local payload

	if [[ -z "${webhook_url}" ]]; then
		log_crit "DISCORD_WEBHOOK_URL is required"
	fi
	if [[ "${webhook_url}" != https://discord.com/api/webhooks/* && "${webhook_url}" != https://ptb.discord.com/api/webhooks/* ]]; then
		log_crit "DISCORD_WEBHOOK_URL does not look like a Discord webhook URL"
	fi
	if ! command -v curl >/dev/null 2>&1; then
		log_crit "curl is required"
	fi

	message="$(build_message)"
	if [[ -n "${mentions}" ]]; then
		message="${mentions} ${message}"
	fi

	payload="{\"username\":\"$(json_escape "${username}")\",\"content\":\"$(json_escape "${message}")\""
	if [[ -n "${avatar_url}" ]]; then
		payload="${payload},\"avatar_url\":\"$(json_escape "${avatar_url}")\""
	fi
	payload="${payload}}"

	if ! curl -fsS --max-time 15 -H 'Content-Type: application/json' -d "${payload}" "${webhook_url}" >/dev/null; then
		log_crit "Failed to send Discord notification"
	fi

	log_info "Discord notification sent"
}

main "$@"
