#!/bin/sh
set -eu

log_info() {
	echo "[info] [drift-radar] $*"
}

log_crit() {
	echo "[crit] [drift-radar] $*" >&2
}

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "${repo_root}"

require_file() {
	path="$1"
	if [ ! -f "${path}" ]; then
		log_crit "Missing required file: ${path}"
		exit 1
	fi
}

require_file "Dockerfile"
require_file "Dockerfile-testing"
require_file "scripts/latest-nzbget-version.sh"
require_file "scripts/latest-binhex-base-tag.sh"

current_stable_nzbget="$(sed -n 's/^ENV NZBGET_VERSION=//p' Dockerfile | head -n1)"
current_testing_nzbget="$(sed -n 's/^ENV NZBGET_VERSION=//p' Dockerfile-testing | head -n1)"
current_stable_base="$(sed -n 's/^ARG BASE_IMAGE_TAG=//p' Dockerfile | head -n1)"
current_testing_base="$(sed -n 's/^ARG BASE_IMAGE_TAG=//p' Dockerfile-testing | head -n1)"

if [ -z "${current_stable_nzbget}" ] || [ -z "${current_testing_nzbget}" ]; then
	log_crit "Unable to read current NZBGet versions from Dockerfile(s)"
	exit 1
fi
if [ -z "${current_stable_base}" ] || [ -z "${current_testing_base}" ]; then
	log_crit "Unable to read current BASE_IMAGE_TAG values from Dockerfile(s)"
	exit 1
fi

log_info "Resolving latest upstream versions"
latest_stable_nzbget="$(./scripts/latest-nzbget-version.sh stable)"
latest_testing_nzbget="$(./scripts/latest-nzbget-version.sh testing)"
latest_base_tag="$(./scripts/latest-binhex-base-tag.sh)"

drift_count=0
status_line() {
	label="$1"
	current="$2"
	latest="$3"
	if [ "${current}" = "${latest}" ]; then
		printf -- '- ✅ %s: `%s` (up to date)\n' "${label}" "${current}"
	else
		drift_count=$((drift_count + 1))
		printf -- '- ⚠️ %s: current `%s`, latest `%s`\n' "${label}" "${current}" "${latest}"
	fi
}

summary_file="$(mktemp)"
trap 'rm -f "${summary_file}"' EXIT INT TERM

{
	echo "## Dependency Drift Radar"
	echo
	echo "- Generated: \`$(date -u '+%Y-%m-%d %H:%M:%S UTC')\`"
	echo "- Repository: \`marc0janssen/nzbgetvpn\`"
	echo
	echo "### NZBGet"
	status_line "Stable" "${current_stable_nzbget}" "${latest_stable_nzbget}"
	status_line "Testing" "${current_testing_nzbget}" "${latest_testing_nzbget}"
	echo
	echo "### Base Image (binhex/arch-int-vpn)"
	status_line "Stable Dockerfile tag" "${current_stable_base}" "${latest_base_tag}"
	status_line "Testing Dockerfile tag" "${current_testing_base}" "${latest_base_tag}"
	echo
	if [ "${drift_count}" -eq 0 ]; then
		echo "✅ No dependency drift detected."
	else
		echo "⚠️ Drift detected in ${drift_count} item(s)."
		echo
		echo "Suggested next actions:"
		echo "- Run \`./build.sh --base newest\` for stable base refresh."
		echo "- Run \`./build-testing.sh --base newest\` for testing base refresh."
		echo "- Run \`./scripts/update-stable.sh <version> --sha256 <sha256>\` for stable NZBGet updates."
		echo "- Run \`./scripts/update-testing.sh <version> --sha256 <sha256>\` for testing NZBGet updates."
	fi
} >"${summary_file}"

cat "${summary_file}"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
	cat "${summary_file}" >>"${GITHUB_STEP_SUMMARY}"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
	{
		if [ "${drift_count}" -eq 0 ]; then
			echo "drift_detected=no"
		else
			echo "drift_detected=yes"
		fi
		echo "drift_count=${drift_count}"
		echo "current_stable_base=${current_stable_base}"
		echo "current_testing_base=${current_testing_base}"
		echo "latest_base_tag=${latest_base_tag}"
		echo "current_stable_nzbget=${current_stable_nzbget}"
		echo "current_testing_nzbget=${current_testing_nzbget}"
		echo "latest_stable_nzbget=${latest_stable_nzbget}"
		echo "latest_testing_nzbget=${latest_testing_nzbget}"
		echo "summary_body<<EOF"
		cat "${summary_file}"
		echo "EOF"
	} >>"${GITHUB_OUTPUT}"
fi

log_info "Drift radar completed (drift_count=${drift_count})"
