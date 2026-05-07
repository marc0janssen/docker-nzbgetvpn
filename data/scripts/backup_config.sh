#!/usr/bin/env bash

set -Eeuo pipefail

log_info() {
	printf '[info] %s\n' "$*"
}

log_crit() {
	printf '[crit] %s\n' "$*" >&2
	exit 1
}

resolve_timestamp_mode() {
	local tz_mode="${NZBGETVPN_TIMESTAMP_TZ:-utc}"

	case "${tz_mode}" in
		utc|local)
			printf '%s' "${tz_mode}"
			;;
		*)
			log_info "NZBGETVPN_TIMESTAMP_TZ must be 'utc' or 'local'; falling back to 'utc'"
			printf 'utc'
			;;
	esac
}

validate_path() {
	local path="$1"
	local var_name="$2"

	if [[ -z "${path}" ]]; then
		log_crit "${var_name} is empty"
	fi
	if [[ "${path}" != /* ]]; then
		log_crit "${var_name} must be an absolute path"
	fi
	if [[ "${path}" == *".."* ]]; then
		log_crit "${var_name} must not contain '..'"
	fi
}

validate_prefix() {
	local prefix="$1"

	if [[ -z "${prefix}" ]]; then
		log_crit "BACKUP_FILENAME_PREFIX is empty"
	fi
	if [[ "${prefix}" =~ [^a-zA-Z0-9._-] ]]; then
		log_crit "BACKUP_FILENAME_PREFIX contains invalid characters"
	fi
}

cleanup_old_backups() {
	local target_dir="$1"
	local prefix="$2"
	local keep="$3"
	local backup_files=()
	local index

	if [[ "${keep}" -lt 1 ]]; then
		return 0
	fi

	while IFS= read -r file; do
		backup_files+=("${file}")
	done < <(ls -1t "${target_dir}/${prefix}"-*.tgz 2>/dev/null || true)

	for ((index = keep; index < ${#backup_files[@]}; index++)); do
		rm -f -- "${backup_files[index]}"
		log_info "Removed old backup '${backup_files[index]}'"
	done
}

main() {
	local source_dir="${BACKUP_SOURCE_DIR:-/config}"
	local target_dir="${BACKUP_TARGET_DIR:-/data/backups}"
	local prefix="${BACKUP_FILENAME_PREFIX:-nzbgetvpn-config-backup}"
	local keep_count="${BACKUP_KEEP_COUNT:-10}"
	local timestamp
	local nanos
	local timestamp_mode
	local source_parent
	local source_name
	local output_file
	local tmp_file

	validate_path "${source_dir}" "BACKUP_SOURCE_DIR"
	validate_path "${target_dir}" "BACKUP_TARGET_DIR"
	validate_prefix "${prefix}"

	if ! [[ "${keep_count}" =~ ^[0-9]+$ ]]; then
		log_crit "BACKUP_KEEP_COUNT must be a non-negative integer"
	fi

	if [[ ! -d "${source_dir}" ]]; then
		log_crit "BACKUP_SOURCE_DIR '${source_dir}' does not exist"
	fi
	if [[ ! -r "${source_dir}" ]]; then
		log_crit "BACKUP_SOURCE_DIR '${source_dir}' is not readable"
	fi

	# Automatically prepare backup destination when missing.
	mkdir -p -- "${target_dir}"
	if [[ ! -w "${target_dir}" ]]; then
		log_crit "BACKUP_TARGET_DIR '${target_dir}' is not writable"
	fi

	timestamp_mode="$(resolve_timestamp_mode)"
	if [[ "${timestamp_mode}" == "utc" ]]; then
		nanos="$(date -u +%N 2>/dev/null || echo 000000000)"
	else
		nanos="$(date +%N 2>/dev/null || echo 000000000)"
	fi
	if ! [[ "${nanos}" =~ ^[0-9]{9}$ ]]; then
		nanos="000000000"
	fi
	if [[ "${timestamp_mode}" == "utc" ]]; then
		timestamp="$(date -u +%Y%m%d-%H%M%S)-${nanos}Z"
	else
		timestamp="$(date +%Y%m%d-%H%M%S)-${nanos}L"
	fi
	output_file="${target_dir}/${prefix}-${timestamp}.tgz"
	tmp_file="${output_file}.tmp"
	source_parent="$(dirname -- "${source_dir}")"
	source_name="$(basename -- "${source_dir}")"

	tar -czf "${tmp_file}" -C "${source_parent}" "${source_name}"
	chmod 600 "${tmp_file}" || true
	mv -f -- "${tmp_file}" "${output_file}"

	log_info "Config backup created at '${output_file}'"

	if [[ "${keep_count}" -gt 0 ]]; then
		cleanup_old_backups "${target_dir}" "${prefix}" "${keep_count}"
	fi
}

main "$@"
