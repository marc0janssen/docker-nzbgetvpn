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

status_path_warn() {
	# Status output should not alter warning counters used for strict readiness.
	echo "[warn] [vpn-selftest] $*"
}

validate_status_file_path() {
	local path="${1:-}"

	if [[ -z "${path}" ]]; then
		return 1
	fi
	if [[ "${path}" != /* ]]; then
		status_path_warn "VPN_SELFTEST_STATUS_FILE must be an absolute path, skipping status write"
		return 1
	fi
	if [[ "${path}" == *..* ]]; then
		status_path_warn "VPN_SELFTEST_STATUS_FILE must not contain '..', skipping status write"
		return 1
	fi
	if [[ "${#path}" -gt 4096 ]]; then
		status_path_warn "VPN_SELFTEST_STATUS_FILE path is too long, skipping status write"
		return 1
	fi
	return 0
}

debounce_path_warn() {
	# Debounce should not alter warning counters used for strict readiness.
	echo "[warn] [vpn-selftest] $*"
}

validate_debounce_file_path() {
	local path="${1:-}"

	if [[ -z "${path}" ]]; then
		return 1
	fi
	if [[ "${path}" != /* ]]; then
		debounce_path_warn "VPN_SELFTEST_DEBOUNCE_FILE must be an absolute path, skipping debounce state"
		return 1
	fi
	if [[ "${path}" == *..* ]]; then
		debounce_path_warn "VPN_SELFTEST_DEBOUNCE_FILE must not contain '..', skipping debounce state"
		return 1
	fi
	if [[ "${#path}" -gt 4096 ]]; then
		debounce_path_warn "VPN_SELFTEST_DEBOUNCE_FILE path is too long, skipping debounce state"
		return 1
	fi
	return 0
}

get_default_runtime_path() {
	local kind="$1"
	local base_path="$2"
	local uid

	if [[ -n "${kind}" && -n "${base_path}" && -e "${base_path}" && ! -w "${base_path}" ]]; then
		uid="$(id -u 2>/dev/null || echo 0)"
		case "${kind}" in
			state)
				state_path_warn "Default state file '${base_path}' exists but is not writable by uid ${uid}; using '${base_path}-uid${uid}'"
				;;
			debounce)
				debounce_path_warn "Default debounce file '${base_path}' exists but is not writable by uid ${uid}; using '${base_path}-uid${uid}'"
				;;
		esac
		echo "${base_path}-uid${uid}"
		return 0
	fi

	echo "${base_path}"
}

get_positive_int_default() {
	local value="${1:-}"
	local default_value="${2}"

	if [[ -z "${value}" ]]; then
		echo "${default_value}"
		return 0
	fi
	if ! [[ "${value}" =~ ^[0-9]+$ ]] || [[ "${value}" -lt 1 ]]; then
		echo "${default_value}"
		return 0
	fi
	echo "${value}"
}

load_debounce_streaks() {
	local path="$1"
	local crit_out_var="$2"
	local warn_out_var="$3"
	local crit=0
	local warn=0

	if [[ -f "${path}" ]]; then
		crit="$(awk -F= '$1=="crit"{print $2}' "${path}" 2>/dev/null | head -n1 || true)"
		warn="$(awk -F= '$1=="warn"{print $2}' "${path}" 2>/dev/null | head -n1 || true)"
	fi
	if ! [[ "${crit}" =~ ^[0-9]+$ ]]; then crit=0; fi
	if ! [[ "${warn}" =~ ^[0-9]+$ ]]; then warn=0; fi

	printf -v "${crit_out_var}" '%s' "${crit}"
	printf -v "${warn_out_var}" '%s' "${warn}"
}

save_debounce_streaks() {
	local path="$1"
	local crit="$2"
	local warn="$3"
	local dir
	local tmp

	dir="$(dirname -- "${path}")"
	if [[ ! -d "${dir}" || ! -w "${dir}" ]]; then
		debounce_path_warn "VPN_SELFTEST_DEBOUNCE_FILE parent directory '${dir}' is unavailable, skipping debounce state"
		return 0
	fi

	tmp="$(mktemp "${dir}/.nzbgetvpn-selftest-debounce.XXXXXX")" || {
		debounce_path_warn "Failed to create temp file for VPN_SELFTEST_DEBOUNCE_FILE in '${dir}', skipping debounce state"
		return 0
	}
	trap 'rm -f -- "${tmp}"' EXIT
	printf 'crit=%s\nwarn=%s\n' "${crit}" "${warn}" > "${tmp}" || {
		debounce_path_warn "Failed to write VPN_SELFTEST_DEBOUNCE_FILE temp, skipping debounce state"
		return 0
	}
	chmod 644 "${tmp}" 2>/dev/null || true
	if ! mv -f -- "${tmp}" "${path}" 2>/dev/null; then
		debounce_path_warn "Failed to replace VPN_SELFTEST_DEBOUNCE_FILE '${path}', skipping debounce state"
		return 0
	fi
	trap - EXIT
}

json_escape() {
	# Minimal JSON string escaping for our controlled values.
	# shellcheck disable=SC2001
	echo -n "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

write_status_json() {
	local path="${VPN_SELFTEST_STATUS_FILE:-}"
	local dir
	local tmp
	local now
	local state="$1"
	local vpn_ip_value="${vpn_ip:-${VPN_IP:-}}"

	validate_status_file_path "${path}" || return 0

	dir="$(dirname -- "${path}")"
	if [[ ! -d "${dir}" || ! -w "${dir}" ]]; then
		status_path_warn "VPN_SELFTEST_STATUS_FILE parent directory '${dir}' is unavailable, skipping status write"
		return 0
	fi

	now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	tmp="$(mktemp "${dir}/.nzbgetvpn-status.XXXXXX")"
	trap 'rm -f -- "${tmp}"' EXIT

	cat >"${tmp}" <<EOF
{"timestamp_utc":"$(json_escape "${now}")","state":"$(json_escape "${state}")","warn_count":${warn_count},"fail_count":${fail_count},"vpn_enabled":"$(json_escape "${VPN_ENABLED:-yes}")","vpn_device_type":"$(json_escape "${VPN_DEVICE_TYPE:-}")","vpn_ip_signal":"$(json_escape "${vpn_ip_value}")","nzbget_port":${VPN_SELFTEST_NZBGET_PORT:-6789},"debounce_crit_streak":${VPN_SELFTEST_DEBOUNCE_CRIT_STREAK:-0},"debounce_warn_streak":${VPN_SELFTEST_DEBOUNCE_WARN_STREAK:-0}}
EOF

	chmod 644 "${tmp}" || true
	mv -f -- "${tmp}" "${path}"
	trap - EXIT
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
	local state_file
	local hook_script="${VPN_SELFTEST_STATE_HOOK:-}"
	local hook_timeout="${VPN_SELFTEST_STATE_HOOK_TIMEOUT:-30}"
	local current_state="$1"
	local previous_state="unknown"
	local dir
	local tmp

	if [[ -n "${VPN_SELFTEST_STATE_FILE:-}" ]]; then
		state_file="${VPN_SELFTEST_STATE_FILE}"
	else
		state_file="$(get_default_runtime_path "state" "/data/nzbgetvpn-selftest-state")"
	fi

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

	# Write atomically and never fail self-test if state tracking cannot persist.
	tmp="$(mktemp "${dir}/.nzbgetvpn-selftest-state.XXXXXX")" || {
		state_path_warn "Failed to create temp file for VPN_SELFTEST_STATE_FILE in '${dir}', skipping state tracking"
		return 0
	}
	trap 'rm -f -- "${tmp}"' EXIT
	printf '%s\n' "${current_state}" > "${tmp}" || {
		state_path_warn "Failed to write VPN_SELFTEST_STATE_FILE temp, skipping state tracking"
		return 0
	}
	chmod 644 "${tmp}" 2>/dev/null || true
	if ! mv -f -- "${tmp}" "${state_file}" 2>/dev/null; then
		state_path_warn "Failed to replace VPN_SELFTEST_STATE_FILE '${state_file}', skipping state tracking"
		return 0
	fi
	trap - EXIT

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
	local debounce_file
	local debounce_crit_required
	local debounce_warn_required
	local debounce_crit_streak=0
	local debounce_warn_streak=0
	local effective_state="ready"

	if [[ -n "${VPN_SELFTEST_DEBOUNCE_FILE:-}" ]]; then
		debounce_file="${VPN_SELFTEST_DEBOUNCE_FILE}"
	else
		debounce_file="$(get_default_runtime_path "debounce" "/data/nzbgetvpn-selftest-debounce")"
	fi

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

	debounce_crit_required="$(get_positive_int_default "${VPN_SELFTEST_DEBOUNCE_CRIT:-1}" 1)"
	debounce_warn_required="$(get_positive_int_default "${VPN_SELFTEST_DEBOUNCE_WARN:-1}" 1)"

	if validate_debounce_file_path "${debounce_file}"; then
		load_debounce_streaks "${debounce_file}" debounce_crit_streak debounce_warn_streak
	fi

	if [[ "${fail_count}" -gt 0 ]]; then
		debounce_crit_streak=$((debounce_crit_streak + 1))
	else
		debounce_crit_streak=0
	fi

	if [[ "${warn_count}" -gt 0 ]]; then
		debounce_warn_streak=$((debounce_warn_streak + 1))
	else
		debounce_warn_streak=0
	fi

	export VPN_SELFTEST_DEBOUNCE_CRIT_STREAK="${debounce_crit_streak}"
	export VPN_SELFTEST_DEBOUNCE_WARN_STREAK="${debounce_warn_streak}"

	if validate_debounce_file_path "${debounce_file}"; then
		save_debounce_streaks "${debounce_file}" "${debounce_crit_streak}" "${debounce_warn_streak}"
	fi

	if [[ "${fail_count}" -gt 0 ]]; then
		if [[ "${debounce_crit_streak}" -ge "${debounce_crit_required}" ]]; then
			effective_state="not_ready"
		else
			log_warn "Critical failures debounced (${debounce_crit_streak}/${debounce_crit_required}); delaying not_ready state"
		fi
	fi

	if [[ "${effective_state}" != "not_ready" ]] && is_enabled "${VPN_SELFTEST_READY_STRICT:-no}" && [[ "${warn_count}" -gt 0 ]]; then
		if [[ "${debounce_warn_streak}" -ge "${debounce_warn_required}" ]]; then
			effective_state="not_ready"
		else
			log_info "Warnings debounced in strict mode (${debounce_warn_streak}/${debounce_warn_required}); keeping ready state"
		fi
	fi

	write_status_json "${effective_state}"
	handle_state_change_hook "${effective_state}"

	if [[ "${effective_state}" == "not_ready" ]]; then
		clear_ready_file
		if [[ "${fail_count}" -gt 0 ]]; then
			log_crit "Self-test finished with ${fail_count} critical issue(s) and ${warn_count} warning(s)"
			exit 1
		fi
		log_info "Self-test finished with ${warn_count} warning(s) but strict mode marked not_ready"
		exit 0
	fi

	update_ready_file
	log_info "Self-test finished successfully with ${warn_count} warning(s)"
}

main "$@"
