#!/usr/bin/env bash
set -Eeuo pipefail

log_warn() {
	echo "[warn] [log-sanitizer] $*" >&2
}

usage() {
	cat <<'EOF'
Usage:
  log_sanitizer.sh [INPUT_FILE] [OUTPUT_FILE]
  log_sanitizer.sh < input.log > output.log

Behavior:
  - Redacts common token/secret assignments and auth headers
  - Redacts IPv4/IPv6 addresses
  - Redacts absolute filesystem paths

Notes:
  - If INPUT_FILE is provided and OUTPUT_FILE is omitted, output goes to stdout.
  - If both INPUT_FILE and OUTPUT_FILE are provided, INPUT_FILE is read and OUTPUT_FILE is written.
EOF
}

sanitize_stream() {
	sed -E \
		-e 's/(Authorization:[[:space:]]*Bearer[[:space:]]+)[^[:space:]]+/\1<redacted-token>/g' \
		-e 's/((NORDVPN_ACCESS_TOKEN|VPN_PASS|VPN_USER|PUSHOVER_APP_TOKEN|PUSHOVER_USER_KEY|TELEGRAM_BOT_TOKEN|DISCORD_WEBHOOK_URL|SOCKS_PASS|SOCKS_USER|API_KEY|ACCESS_TOKEN|SECRET_KEY|PASSWORD)[[:space:]]*[:=][[:space:]]*)[^[:space:]"]+/\1<redacted-secret>/g' \
		-e 's/([?&](token|access_token|apikey|api_key|password|passwd|secret|key)=)[^&[:space:]]+/\1<redacted-query>/g' \
		-e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/<redacted-ipv4>/g' \
		-e 's/\b([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}\b/<redacted-ipv6>/g' \
		-e 's#(^|[[:space:]"'\''=])(/[^[:space:]"'\'']+)#\1<redacted-path>#g'
}

main() {
	local input_file="${1:-}"
	local output_file="${2:-}"

	if [[ "${input_file}" == "-h" || "${input_file}" == "--help" ]]; then
		usage
		exit 0
	fi

	if [[ -n "${input_file}" && ! -f "${input_file}" ]]; then
		echo "[crit] [log-sanitizer] Input file '${input_file}' does not exist" >&2
		exit 1
	fi

	if [[ -n "${input_file}" && -n "${output_file}" ]]; then
		if [[ "${input_file}" == "${output_file}" ]]; then
			echo "[crit] [log-sanitizer] Refusing to overwrite input file in place; use a different output path" >&2
			exit 1
		fi
		sanitize_stream < "${input_file}" > "${output_file}"
		echo "[info] [log-sanitizer] Wrote sanitized output to '${output_file}'"
		return
	fi

	if [[ -n "${input_file}" ]]; then
		sanitize_stream < "${input_file}"
		return
	fi

	sanitize_stream
}

main "$@"
