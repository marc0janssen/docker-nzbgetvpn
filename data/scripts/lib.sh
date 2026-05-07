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
