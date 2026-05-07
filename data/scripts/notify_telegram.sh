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
	local bot_token="${TELEGRAM_BOT_TOKEN:-}"
	local chat_id="${TELEGRAM_CHAT_ID:-}"
	local topic_id="${TELEGRAM_MESSAGE_THREAD_ID:-}"
	local parse_mode="${TELEGRAM_PARSE_MODE:-}"
	local message
	local api_url

	if [[ -z "${bot_token}" ]]; then
		log_crit "TELEGRAM_BOT_TOKEN is required"
	fi
	if [[ -z "${chat_id}" ]]; then
		log_crit "TELEGRAM_CHAT_ID is required"
	fi
	if ! command -v curl >/dev/null 2>&1; then
		log_crit "curl is required"
	fi

	message="$(build_message)"
	api_url="https://api.telegram.org/bot${bot_token}/sendMessage"

	if [[ -n "${topic_id}" ]]; then
		if ! curl -fsS --max-time 15 -X POST "${api_url}" \
			--data-urlencode "chat_id=${chat_id}" \
			--data-urlencode "message_thread_id=${topic_id}" \
			--data-urlencode "text=${message}" \
			${parse_mode:+--data-urlencode "parse_mode=${parse_mode}"} \
			>/dev/null; then
			log_crit "Failed to send Telegram notification"
		fi
	else
		if ! curl -fsS --max-time 15 -X POST "${api_url}" \
			--data-urlencode "chat_id=${chat_id}" \
			--data-urlencode "text=${message}" \
			${parse_mode:+--data-urlencode "parse_mode=${parse_mode}"} \
			>/dev/null; then
			log_crit "Failed to send Telegram notification"
		fi
	fi

	log_info "Telegram notification sent"
}

main "$@"
