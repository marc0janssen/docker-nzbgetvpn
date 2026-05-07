#!/usr/bin/env bash
set -Eeuo pipefail

log_info() {
	printf '[info] [benchmark-endpoints] %s\n' "$*"
}

log_warn() {
	printf '[warn] [benchmark-endpoints] %s\n' "$*" >&2
}

log_crit() {
	printf '[crit] [benchmark-endpoints] %s\n' "$*" >&2
	exit 1
}

is_positive_integer() {
	[[ "${1:-}" =~ ^[0-9]+$ ]] && [[ "${1}" -gt 0 ]]
}

trim() {
	printf '%s' "${1:-}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

json_escape() {
	printf '%s' "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

validate_output_path() {
	local path="${1:-}"
	if [[ -z "${path}" ]]; then
		return 1
	fi
	[[ "${path}" == /* ]] || log_crit "BENCHMARK_OUTPUT_FILE must be an absolute path"
	[[ "${path}" != *..* ]] || log_crit "BENCHMARK_OUTPUT_FILE must not contain '..'"
}

fetch_metrics() {
	local url="$1"
	local timeout_secs="$2"
	curl --fail --silent --show-error --location --max-time "${timeout_secs}" --output /dev/null \
		--write-out '%{time_starttransfer} %{speed_download} %{http_code}' "${url}"
}

main() {
	local endpoints_raw="${BENCHMARK_ENDPOINTS:-https://speed.cloudflare.com/__down?bytes=4000000,https://proof.ovh.net/files/10Mb.dat}"
	local attempts="${BENCHMARK_ATTEMPTS:-2}"
	local timeout_secs="${BENCHMARK_TIMEOUT:-20}"
	local output_file="${BENCHMARK_OUTPUT_FILE:-}"
	local best_file="${BENCHMARK_BEST_FILE:-}"
	local endpoint
	local attempt
	local metrics
	local ttfb
	local speed_bps
	local status_code
	local ttfb_ms
	local speed_mbps
	local score
	local sum_ttfb_ms
	local sum_speed_mbps
	local avg_ttfb_ms
	local avg_speed_mbps
	local success_count
	local best_endpoint=""
	local best_score="-1"
	local best_speed="0"
	local best_ttfb="999999"
	local result_lines=()
	local tmp

	command -v curl >/dev/null 2>&1 || log_crit "Required command 'curl' is not installed"
	is_positive_integer "${attempts}" || log_crit "BENCHMARK_ATTEMPTS must be a positive integer"
	is_positive_integer "${timeout_secs}" || log_crit "BENCHMARK_TIMEOUT must be a positive integer"

	IFS=',' read -r -a endpoints <<< "${endpoints_raw}"
	[[ "${#endpoints[@]}" -gt 0 ]] || log_crit "BENCHMARK_ENDPOINTS is empty"

	for endpoint in "${endpoints[@]}"; do
		endpoint="$(trim "${endpoint}")"
		[[ -n "${endpoint}" ]] || continue

		success_count=0
		ttfb_ms=0
		speed_mbps=0
		score=0
		sum_ttfb_ms=0
		sum_speed_mbps=0

		for ((attempt = 1; attempt <= attempts; attempt++)); do
			metrics="$(fetch_metrics "${endpoint}" "${timeout_secs}" || true)"
			if [[ -z "${metrics}" ]]; then
				continue
			fi

			read -r ttfb speed_bps status_code <<< "${metrics}"
			if [[ "${status_code}" -lt 200 || "${status_code}" -ge 400 ]]; then
				continue
			fi

			ttfb_ms="$(awk -v secs="${ttfb}" 'BEGIN {printf "%.0f", secs*1000}')"
			speed_mbps="$(awk -v bps="${speed_bps}" 'BEGIN {printf "%.2f", (bps*8)/1000000}')"
			success_count=$((success_count + 1))
			sum_ttfb_ms="$(awk -v total="${sum_ttfb_ms}" -v value="${ttfb_ms}" 'BEGIN {printf "%.6f", total+value}')"
			sum_speed_mbps="$(awk -v total="${sum_speed_mbps}" -v value="${speed_mbps}" 'BEGIN {printf "%.6f", total+value}')"
		done

		if [[ "${success_count}" -eq 0 ]]; then
			result_lines+=("${endpoint}|fail|0|0|0")
			log_warn "Endpoint '${endpoint}' failed all ${attempts} attempt(s)"
			continue
		fi

		avg_ttfb_ms="$(awk -v total="${sum_ttfb_ms}" -v n="${success_count}" 'BEGIN {printf "%.0f", total/n}')"
		avg_speed_mbps="$(awk -v total="${sum_speed_mbps}" -v n="${success_count}" 'BEGIN {printf "%.2f", total/n}')"
		score="$(awk -v speed="${avg_speed_mbps}" -v latency="${avg_ttfb_ms}" 'BEGIN {printf "%.2f", (speed*1000)/(latency+1)}')"

		result_lines+=("${endpoint}|ok|${avg_ttfb_ms}|${avg_speed_mbps}|${score}")
		log_info "Endpoint '${endpoint}' latency=${avg_ttfb_ms}ms speed=${avg_speed_mbps}Mbps score=${score}"

		if awk -v current="${score}" -v best="${best_score}" 'BEGIN {exit (current > best) ? 0 : 1}'; then
			best_score="${score}"
			best_endpoint="${endpoint}"
			best_speed="${avg_speed_mbps}"
			best_ttfb="${avg_ttfb_ms}"
		fi
	done

	if [[ -z "${best_endpoint}" ]]; then
		log_crit "No endpoint produced a successful benchmark result"
	fi

	log_info "Best endpoint: ${best_endpoint} (latency=${best_ttfb}ms speed=${best_speed}Mbps score=${best_score})"

	if [[ -n "${best_file}" ]]; then
		[[ "${best_file}" == /* ]] || log_crit "BENCHMARK_BEST_FILE must be an absolute path"
		[[ "${best_file}" != *..* ]] || log_crit "BENCHMARK_BEST_FILE must not contain '..'"
		printf '%s\n' "${best_endpoint}" > "${best_file}"
		log_info "Wrote best endpoint to '${best_file}'"
	fi

	if validate_output_path "${output_file}"; then
		local dir
		dir="$(dirname -- "${output_file}")"
		[[ -d "${dir}" ]] || mkdir -p -- "${dir}"
		[[ -w "${dir}" ]] || log_crit "BENCHMARK_OUTPUT_FILE parent directory '${dir}' is not writable"

		tmp="$(mktemp "${dir}/.benchmark-endpoints.XXXXXX")"
		trap 'rm -f -- "${tmp}"' EXIT

		{
			printf '{"best_endpoint":"%s","best_latency_ms":%s,"best_speed_mbps":%s,"best_score":%s,"results":[' \
				"$(json_escape "${best_endpoint}")" "${best_ttfb}" "${best_speed}" "${best_score}"
			local first=1
			local line url status latency speed result_score
			for line in "${result_lines[@]}"; do
				IFS='|' read -r url status latency speed result_score <<< "${line}"
				if [[ "${first}" -eq 0 ]]; then
					printf ','
				fi
				first=0
				printf '{"endpoint":"%s","status":"%s","latency_ms":%s,"speed_mbps":%s,"score":%s}' \
					"$(json_escape "${url}")" "$(json_escape "${status}")" "${latency}" "${speed}" "${result_score}"
			done
			printf ']}\n'
		} > "${tmp}"

		chmod 600 "${tmp}" || true
		mv -f -- "${tmp}" "${output_file}"
		trap - EXIT
		log_info "Wrote benchmark JSON to '${output_file}'"
	fi
}

main "$@"
