#!/usr/bin/env bash
set -Eeuo pipefail

log_info() {
	printf '[info] [upgrade-check] %s\n' "$*"
}

log_warn() {
	printf '[warn] [upgrade-check] %s\n' "$*" >&2
}

log_crit() {
	printf '[crit] [upgrade-check] %s\n' "$*" >&2
	exit 1
}

is_positive_integer() {
	[[ "${1:-}" =~ ^[0-9]+$ ]] && [[ "${1}" -gt 0 ]]
}

semver_gt() {
	local lhs="$1"
	local rhs="$2"
	local l1 l2 l3 r1 r2 r3

	IFS='.' read -r l1 l2 l3 <<<"${lhs}"
	IFS='.' read -r r1 r2 r3 <<<"${rhs}"
	l1="${l1:-0}"
	l2="${l2:-0}"
	l3="${l3:-0}"
	r1="${r1:-0}"
	r2="${r2:-0}"
	r3="${r3:-0}"

	if ((l1 > r1)); then return 0; fi
	if ((l1 < r1)); then return 1; fi
	if ((l2 > r2)); then return 0; fi
	if ((l2 < r2)); then return 1; fi
	((l3 > r3))
}

get_current_version() {
	local version_file="${UPGRADE_CHECK_LOCAL_VERSION_FILE:-/usr/local/share/nzbgetvpn/VERSION}"
	local value

	if [[ ! -f "${version_file}" ]]; then
		log_warn "Local version file '${version_file}' not found"
		return 1
	fi

	value="$(sed -n '1p' "${version_file}" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	if ! [[ "${value}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		log_warn "Local version '${value}' is not semantic versioning"
		return 1
	fi

	printf '%s' "${value}"
}

fetch_url() {
	local timeout_secs="$1"
	local url="$2"

	if command -v curl >/dev/null 2>&1; then
		curl --fail --silent --show-error --location --max-time "${timeout_secs}" "${url}"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -T "${timeout_secs}" -O - "${url}"
	else
		log_crit "Neither curl nor wget is available"
	fi
}

extract_remote_version() {
	local timeout_secs="$1"
	local branch="$2"
	local repo="$3"
	local value

	value="$(fetch_url "${timeout_secs}" "https://raw.githubusercontent.com/${repo}/${branch}/VERSION" | sed -n '1p' | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	if ! [[ "${value}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		log_warn "Remote version '${value}' is not semantic versioning"
		return 1
	fi
	printf '%s' "${value}"
}

get_local_nzbget_version() {
	local value="${UPGRADE_CHECK_LOCAL_NZBGET_VERSION:-${NZBGET_VERSION:-}}"
	local detected

	if [[ -n "${value}" ]]; then
		value="$(printf '%s' "${value}" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
		printf '%s' "${value}"
		return 0
	fi

	if command -v nzbget >/dev/null 2>&1; then
		detected="$(nzbget --version 2>/dev/null | awk 'match($0, /[0-9]+\.[0-9]+([-A-Za-z0-9.]+)?/) {print substr($0,RSTART,RLENGTH); exit}')"
		if [[ -n "${detected}" ]]; then
			printf '%s' "${detected}"
			return 0
		fi
	fi

	return 1
}

extract_remote_nzbget_versions() {
	local timeout_secs="$1"
	local branch="$2"
	local repo="$3"
	local readme
	local stable
	local testing

	readme="$(fetch_url "${timeout_secs}" "https://raw.githubusercontent.com/${repo}/${branch}/README.md" || true)"
	if [[ -z "${readme}" ]]; then
		return 1
	fi

	stable="$(printf '%s\n' "${readme}" | awk -F': ' '/^\* NZBGET Current stable version:/ {print $2; exit}' | tr -d '\r' | sed -e 's/[[:space:]]*$//')"
	testing="$(printf '%s\n' "${readme}" | awk -F': ' '/^\* NZBGET Current testing version:/ {print $2; exit}' | tr -d '\r' | sed -e 's/[[:space:]]*$//')"

	if [[ -z "${stable}" && -z "${testing}" ]]; then
		return 1
	fi

	printf '%s|%s' "${stable}" "${testing}"
}

print_changelog_impact() {
	local timeout_secs="$1"
	local branch="$2"
	local repo="$3"
	local current_version="$4"
	local limit="$5"

	log_info "Changelog impact (newer than ${current_version}):"
	fetch_url "${timeout_secs}" "https://raw.githubusercontent.com/${repo}/${branch}/CHANGELOG.md" |
		awk -v current="${current_version}" -v max_sections="${limit}" '
/^## \[/ {
	version = $0
	sub(/^## \[/, "", version)
	sub(/\].*$/, "", version)
	if (version == current) {
		exit
	}
	sections += 1
	if (sections > max_sections) {
		exit
	}
}
sections > 0 { print }
' || log_warn "Could not extract changelog sections from remote changelog"
}

main() {
	local repo="${UPGRADE_CHECK_REPO:-marc0janssen/nzbgetvpn}"
	local branch="${UPGRADE_CHECK_BRANCH:-develop}"
	local channel="${UPGRADE_CHECK_CHANNEL:-stable}"
	local timeout_secs="${UPGRADE_CHECK_TIMEOUT:-15}"
	local changelog_limit="${UPGRADE_CHECK_CHANGELOG_LIMIT:-4}"
	local local_version
	local remote_version
	local local_nzbget_version=""
	local remote_nzbget_versions
	local remote_nzbget_stable=""
	local remote_nzbget_testing=""
	local selected_nzbget_remote=""
	local selected_channel
	local remote_metadata_available=1

	if ! is_positive_integer "${timeout_secs}"; then
		log_warn "UPGRADE_CHECK_TIMEOUT '${timeout_secs}' is invalid, using 15"
		timeout_secs=15
	fi
	if ! is_positive_integer "${changelog_limit}"; then
		log_warn "UPGRADE_CHECK_CHANGELOG_LIMIT '${changelog_limit}' is invalid, using 4"
		changelog_limit=4
	fi

	local_version="$(get_current_version || true)"
	if [[ -z "${local_version}" ]]; then
		log_crit "Could not determine local NZBGetVPN version"
	fi

	remote_version="$(extract_remote_version "${timeout_secs}" "${branch}" "${repo}" || true)"
	if [[ -z "${remote_version}" ]]; then
		log_warn "Could not fetch remote NZBGetVPN version from ${repo}:${branch} (network/DNS issue?)"
		remote_metadata_available=0
	fi

	log_info "Local NZBGetVPN version: ${local_version}"
	if [[ "${remote_metadata_available}" -eq 1 ]]; then
		log_info "Remote NZBGetVPN version (${repo}:${branch}): ${remote_version}"
	else
		log_warn "Remote NZBGetVPN metadata unavailable; skipping remote comparison"
	fi

	local_nzbget_version="$(get_local_nzbget_version || true)"
	if [[ "${remote_metadata_available}" -eq 1 ]]; then
		remote_nzbget_versions="$(extract_remote_nzbget_versions "${timeout_secs}" "${branch}" "${repo}" || true)"
	fi
	if [[ -n "${remote_nzbget_versions}" ]]; then
		remote_nzbget_stable="${remote_nzbget_versions%%|*}"
		remote_nzbget_testing="${remote_nzbget_versions#*|}"
	fi

	if [[ -n "${local_nzbget_version}" ]]; then
		log_info "Local NZBGet app version: ${local_nzbget_version}"
	else
		log_warn "Could not determine local NZBGet app version"
	fi
	if [[ -n "${remote_nzbget_stable}" ]]; then
		log_info "Remote NZBGet stable version (${repo}:${branch}): ${remote_nzbget_stable}"
	fi
	if [[ -n "${remote_nzbget_testing}" ]]; then
		log_info "Remote NZBGet testing version (${repo}:${branch}): ${remote_nzbget_testing}"
	fi

	selected_channel="${channel}"
	if [[ "${selected_channel}" != "stable" && "${selected_channel}" != "testing" ]]; then
		if [[ "${local_nzbget_version}" == *"testing"* ]]; then
			selected_channel="testing"
		else
			selected_channel="stable"
		fi
	fi
	if [[ "${selected_channel}" == "testing" ]]; then
		selected_nzbget_remote="${remote_nzbget_testing}"
	else
		selected_nzbget_remote="${remote_nzbget_stable}"
	fi

	if [[ "${remote_metadata_available}" -eq 1 ]] && semver_gt "${remote_version}" "${local_version}"; then
		log_warn "Update available: ${local_version} -> ${remote_version}"
		log_info "Suggested update command:"
		printf 'docker pull %s:%s\n' "${repo}" "${channel}"
		printf 'docker pull %s:<nzbget-version>-image-v%s\n' "${repo}" "${remote_version}"
		print_changelog_impact "${timeout_secs}" "${branch}" "${repo}" "${local_version}" "${changelog_limit}"
		if [[ -n "${local_nzbget_version}" && -n "${selected_nzbget_remote}" && "${selected_nzbget_remote}" != "${local_nzbget_version}" ]]; then
			log_warn "NZBGet app update available (${selected_channel}): ${local_nzbget_version} -> ${selected_nzbget_remote}"
		fi
		exit 0
	fi

	if [[ "${remote_metadata_available}" -eq 1 ]] && [[ -n "${local_nzbget_version}" && -n "${selected_nzbget_remote}" && "${selected_nzbget_remote}" != "${local_nzbget_version}" ]]; then
		log_warn "NZBGet app update available (${selected_channel}): ${local_nzbget_version} -> ${selected_nzbget_remote}"
		log_info "No newer NZBGetVPN image metadata detected, but NZBGet app version differs."
		exit 0
	fi

	if [[ "${remote_metadata_available}" -eq 0 ]]; then
		log_info "Local metadata check completed. Re-run when network/DNS to GitHub is available."
		exit 0
	fi

	log_info "No newer NZBGetVPN image metadata detected (local is up to date)."
}

main "$@"
