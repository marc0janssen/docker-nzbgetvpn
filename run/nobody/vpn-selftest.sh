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
	netstat -lnt | awk '$6 == "LISTEN" && $4 ~ /\.6789$/ {found=1} END {exit(found?0:1)}'
}

check_nzbget_state() {
	local attempt
	local max_attempts=24

	if ! pgrep -x nzbget >/dev/null 2>&1; then
		log_warn "NZBGet process is not running at self-test time"
		return
	fi

	for ((attempt = 1; attempt <= max_attempts; attempt++)); do
		if nzbget_listening; then
			log_info "NZBGet process is running and listening on port 6789"
			return
		fi
		sleep 0.5
	done

	log_warn "NZBGet process is running but port 6789 is not listening yet"
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
		log_crit "Self-test finished with ${fail_count} critical issue(s) and ${warn_count} warning(s)"
		exit 1
	fi

	log_info "Self-test finished successfully with ${warn_count} warning(s)"
}

main "$@"
