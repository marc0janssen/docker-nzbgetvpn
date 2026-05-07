#!/usr/bin/env bash
set -Eeuo pipefail

is_enabled() {
	case "${1:-}" in
		yes|true|1)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

main() {
	local selftest_script="/home/nobody/vpn-selftest.sh"
	local tmp_output

	if ! is_enabled "${VPN_HEALTHCHECK_ENABLED:-yes}"; then
		exit 0
	fi

	if [[ ! -x "${selftest_script}" ]]; then
		echo "[crit] [healthcheck] Missing self-test script '${selftest_script}'"
		exit 1
	fi

	tmp_output="$(mktemp /tmp/nzbgetvpn-healthcheck.XXXXXX)"
	trap 'rm -f -- "${tmp_output}"' EXIT

	# Disable side effects during docker healthcheck probes.
	if VPN_SELFTEST_READY_FILE="" VPN_SELFTEST_STATE_FILE="" VPN_SELFTEST_STATE_HOOK="" VPN_SELFTEST_STATUS_FILE="" VPN_SELFTEST_DEBOUNCE_FILE="" "${selftest_script}" >"${tmp_output}" 2>&1; then
		exit 0
	fi

	echo "[crit] [healthcheck] VPN self-test failed"
	sed 's/^/[crit] [healthcheck] /' "${tmp_output}"
	exit 1
}

main "$@"
