#!/usr/bin/env bash
set -Eeuo pipefail

fail_count=0
warn_count=0

log_info() {
	echo "[info] [vpn-selftest] $*"
}

log_warn() {
	echo "[warn] [vpn-selftest] $*"
	warn_count=$((warn_count + 1))
}

log_crit() {
	echo "[crit] [vpn-selftest] $*"
	fail_count=$((fail_count + 1))
}

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

ready_path_warn() {
	# Does not increment warn_count; path validation is orthogonal to VPN/NZBGet checks.
	echo "[warn] [vpn-selftest] $*"
}

validate_ready_file_path() {
	local path="${1:-}"

	if [[ -z "${path}" ]]; then
		return 1
	fi
	if [[ "${path}" != /* ]]; then
		ready_path_warn "VPN_SELFTEST_READY_FILE must be an absolute path, ignoring ready file"
		return 1
	fi
	if [[ "${path}" == *..* ]]; then
		ready_path_warn "VPN_SELFTEST_READY_FILE must not contain '..', ignoring ready file"
		return 1
	fi
	if [[ "${#path}" -gt 4096 ]]; then
		ready_path_warn "VPN_SELFTEST_READY_FILE path is too long, ignoring ready file"
		return 1
	fi
	return 0
}

clear_ready_file() {
	local path="${VPN_SELFTEST_READY_FILE:-}"

	validate_ready_file_path "${path}" || return 0
	rm -f -- "${path}"
}

write_ready_file() {
	local path="${VPN_SELFTEST_READY_FILE:-}"
	local dir
	local tmp

	if ! validate_ready_file_path "${path}"; then
		return 0
	fi

	dir="$(dirname -- "${path}")"
	if [[ ! -d "${dir}" ]]; then
		ready_path_warn "VPN_SELFTEST_READY_FILE parent directory '${dir}' does not exist, skipping ready file"
		return 0
	fi
	if [[ ! -w "${dir}" ]]; then
		ready_path_warn "VPN_SELFTEST_READY_FILE parent directory '${dir}' is not writable, skipping ready file"
		return 0
	fi

	tmp="$(mktemp "${dir}/.nzbgetvpn-ready.XXXXXX")"
	trap 'rm -f -- "${tmp}"' EXIT
	printf 'ok %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${tmp}"
	chmod 644 "${tmp}"
	mv -f -- "${tmp}" "${path}"
	trap - EXIT
	log_info "Wrote ready signal file '${path}'"
}

update_ready_file() {
	local path="${VPN_SELFTEST_READY_FILE:-}"

	if [[ -z "${path}" ]]; then
		return 0
	fi

	if is_enabled "${VPN_SELFTEST_READY_STRICT:-no}" && [[ "${warn_count}" -gt 0 ]]; then
		clear_ready_file
		log_info "Ready file not written (VPN_SELFTEST_READY_STRICT and ${warn_count} warning(s))"
		return 0
	fi

	write_ready_file
}

state_path_warn() {
	# State tracking should not alter warning counters used for strict readiness.
	echo "[warn] [vpn-selftest] $*"
}

validate_state_file_path() {
	local path="${1:-}"

	if [[ -z "${path}" ]]; then
		return 1
	fi
	if [[ "${path}" != /* ]]; then
		state_path_warn "VPN_SELFTEST_STATE_FILE must be an absolute path, skipping state tracking"
		return 1
	fi
	if [[ "${path}" == *..* ]]; then
		state_path_warn "VPN_SELFTEST_STATE_FILE must not contain '..', skipping state tracking"
		return 1
	fi
	if [[ "${#path}" -gt 4096 ]]; then
		state_path_warn "VPN_SELFTEST_STATE_FILE path is too long, skipping state tracking"
		return 1
	fi
	return 0
}

run_script_with_timeout() {
	local timeout_secs="$1"
	shift

	if command -v timeout >/dev/null 2>&1; then
		timeout --kill-after=5s "${timeout_secs}s" "$@"
	else
		"$@"
	fi
}

handle_state_change_hook() {
	local state_file="${VPN_SELFTEST_STATE_FILE:-/tmp/nzbgetvpn-selftest-state}"
	local hook_script="${VPN_SELFTEST_STATE_HOOK:-}"
	local hook_timeout="${VPN_SELFTEST_STATE_HOOK_TIMEOUT:-30}"
	local current_state="$1"
	local previous_state="unknown"
	local dir

	validate_state_file_path "${state_file}" || return 0
	dir="$(dirname -- "${state_file}")"
	if [[ ! -d "${dir}" || ! -w "${dir}" ]]; then
		state_path_warn "VPN_SELFTEST_STATE_FILE parent directory '${dir}' is unavailable, skipping state tracking"
		return 0
	fi

	if [[ -f "${state_file}" ]]; then
		previous_state="$(cat "${state_file}" 2>/dev/null || true)"
		case "${previous_state}" in
			ready|not_ready)
				;;
			*)
				previous_state="unknown"
				;;
		esac
	fi

	printf '%s\n' "${current_state}" > "${state_file}"

	if [[ -z "${hook_script}" ]]; then
		return 0
	fi
	if [[ "${previous_state}" == "unknown" || "${previous_state}" == "${current_state}" ]]; then
		return 0
	fi
	if [[ ! -x "${hook_script}" ]]; then
		state_path_warn "VPN_SELFTEST_STATE_HOOK '${hook_script}' is not executable, skipping hook"
		return 0
	fi
	if ! [[ "${hook_timeout}" =~ ^[0-9]+$ ]] || [[ "${hook_timeout}" -lt 1 ]]; then
		state_path_warn "VPN_SELFTEST_STATE_HOOK_TIMEOUT '${hook_timeout}' is invalid, using 30 seconds"
		hook_timeout=30
	fi

	log_info "Self-test state changed (${previous_state} -> ${current_state}), running '${hook_script}'"
	if ! VPN_SELFTEST_PREVIOUS_STATE="${previous_state}" VPN_SELFTEST_CURRENT_STATE="${current_state}" VPN_SELFTEST_WARN_COUNT="${warn_count}" VPN_SELFTEST_FAIL_COUNT="${fail_count}" run_script_with_timeout "${hook_timeout}" "${hook_script}"; then
		state_path_warn "VPN_SELFTEST_STATE_HOOK '${hook_script}' failed or timed out"
	fi
}

check_dir_writable() {
	local dir_path="$1"
	if [[ ! -d "${dir_path}" ]]; then
		log_crit "Required directory '${dir_path}' does not exist"
		return
	fi
	if [[ ! -w "${dir_path}" ]]; then
		log_crit "Required directory '${dir_path}' is not writable"
		return
	fi
	log_info "Directory '${dir_path}' is writable"
}

check_default_route() {
	if ip route show default | awk 'NF {found=1} END {exit(found?0:1)}'; then
		log_info "Default route is present"
	else
		log_crit "No default route detected inside container"
	fi
}

check_dns_nameserver() {
	if awk '/^nameserver[[:space:]]+[0-9a-fA-F:.]+$/ {found=1} END {exit(found?0:1)}' /etc/resolv.conf; then
		log_info "Resolver nameserver entry detected in /etc/resolv.conf"
	else
		log_warn "No nameserver entry detected in /etc/resolv.conf"
	fi
}

check_vpn_device() {
	local device="${VPN_DEVICE_TYPE:-}"
	if [[ -z "${device}" ]]; then
		log_warn "VPN_DEVICE_TYPE is not set; skipping interface existence check"
		return
	fi
	if ip link show "${device}" >/dev/null 2>&1; then
		log_info "VPN device '${device}' exists"
	else
		log_crit "VPN device '${device}' is not present"
	fi
}

check_vpn_ip_signal() {
	local vpn_ip_value="${vpn_ip:-${VPN_IP:-}}"
	local device="${VPN_DEVICE_TYPE:-}"

	if [[ -z "${vpn_ip_value}" && -n "${device}" ]]; then
		vpn_ip_value="$(ip -4 -o addr show dev "${device}" 2>/dev/null | awk '{print $4}' | head -n1 | cut -d/ -f1)"
	fi

	if [[ -n "${vpn_ip_value}" ]]; then
		log_info "VPN IP signal detected (${vpn_ip_value})"
	else
		log_warn "VPN IP signal is empty at self-test time"
	fi
}

nzbget_listening() {
	local port="$1"
	netstat -lnt | awk -v port="${port}" '$6 == "LISTEN" && $4 ~ ":" port "$" {found=1} END {exit(found?0:1)}'
}

check_nzbget_state() {
	local attempt
	local max_attempts=24
	local nzbget_port="${VPN_SELFTEST_NZBGET_PORT:-6789}"

	if ! [[ "${nzbget_port}" =~ ^[0-9]+$ ]] || [[ "${nzbget_port}" -lt 1 ]] || [[ "${nzbget_port}" -gt 65535 ]]; then
		log_warn "VPN_SELFTEST_NZBGET_PORT '${nzbget_port}' is invalid, using default port 6789"
		nzbget_port=6789
	fi

	if ! pgrep -x nzbget >/dev/null 2>&1; then
		log_warn "NZBGet process is not running at self-test time"
		return
	fi

	for ((attempt = 1; attempt <= max_attempts; attempt++)); do
		if nzbget_listening "${nzbget_port}"; then
			log_info "NZBGet process is running and listening on port ${nzbget_port}"
			return
		fi
		sleep 0.5
	done

	log_warn "NZBGet process is running but port ${nzbget_port} is not listening yet"
}

main() {
	log_info "Starting internal self-test"
	check_dir_writable "/config"
	check_dir_writable "/data"
	check_default_route
	check_dns_nameserver

	if is_enabled "${VPN_ENABLED:-yes}"; then
		check_vpn_device
		check_vpn_ip_signal
	else
		log_info "VPN is disabled; skipping VPN-specific checks"
	fi

	check_nzbget_state

	if [[ "${fail_count}" -gt 0 ]]; then
		handle_state_change_hook "not_ready"
		clear_ready_file
		log_crit "Self-test finished with ${fail_count} critical issue(s) and ${warn_count} warning(s)"
		exit 1
	fi

	if is_enabled "${VPN_SELFTEST_READY_STRICT:-no}" && [[ "${warn_count}" -gt 0 ]]; then
		handle_state_change_hook "not_ready"
	else
		handle_state_change_hook "ready"
	fi
	update_ready_file
	log_info "Self-test finished successfully with ${warn_count} warning(s)"
}

main "$@"
