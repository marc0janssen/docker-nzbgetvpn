#!/bin/sh

set -eu

REPO_API="https://api.github.com/repos/nzbgetcom/nzbget"
REPO_RELEASES_ASSETS_URL="https://github.com/nzbgetcom/nzbget/releases/expanded_assets/testing"

show_help() {
	cat <<EOF
Usage: $0 <stable|testing>

Print the newest NZBGet version for the requested channel.

stable:
  Reads the latest stable GitHub release tag, for example v26.1 -> 26.1.

testing:
  Reads the current testing release assets and extracts the linux installer
  version, for example nzbget-26.2-testing-20260501-bin-linux.run.
EOF
}

fetch_api() {
	url="$1"

	auth_header=""
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		auth_header="Authorization: Bearer ${GITHUB_TOKEN}"
	elif [ -n "${GH_TOKEN:-}" ]; then
		auth_header="Authorization: Bearer ${GH_TOKEN}"
	fi

	if [ -n "${auth_header}" ]; then
		curl -L --fail --silent --show-error \
			-H "${auth_header}" \
			-H "Accept: application/vnd.github+json" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			"${url}"
		return
	fi

	curl -L --fail --silent --show-error \
		-H "Accept: application/vnd.github+json" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"${url}"
}

fetch_testing_asset_from_html() {
	curl -L --fail --silent --show-error \
		-H "User-Agent: nzbgetvpn-latest-version-script" \
		"${REPO_RELEASES_ASSETS_URL}" |
		sed -n 's~.*href="[^"]*/download/testing/\(nzbget-[^"]*-bin-linux\.run\)".*~\1~p' |
		grep -E '^nzbget-[0-9].*-testing-[0-9]+-bin-linux\.run$' |
		head -n 1
}

latest_stable() {
	tag_name=$(fetch_api "${REPO_API}/releases/latest" |
		sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' |
		head -n 1)

	if [ -z "${tag_name}" ]; then
		echo "Unable to determine latest stable NZBGet release" >&2
		exit 1
	fi

	case "${tag_name}" in
	v*testing* | *testing*)
		echo "Latest stable release tag '${tag_name}' looks like a testing release" >&2
		exit 1
		;;
	v*)
		printf '%s\n' "${tag_name#v}"
		;;
	*)
		printf '%s\n' "${tag_name}"
		;;
	esac
}

latest_testing() {
	asset_name=$(
		(fetch_api "${REPO_API}/releases/tags/testing" 2>/dev/null || true) |
			sed -n 's/.*"name": *"\(nzbget-[^"]*-bin-linux\.run\)".*/\1/p' |
			head -n 1
	)

	if [ -z "${asset_name}" ]; then
		asset_name="$(fetch_testing_asset_from_html 2>/dev/null || true)"
	fi

	if [ -z "${asset_name}" ]; then
		echo "Unable to determine latest testing NZBGet linux installer asset (API and HTML fallback failed)" >&2
		exit 1
	fi

	printf '%s\n' "${asset_name}" | sed 's/^nzbget-//;s/-bin-linux\.run$//'
}

case "${1:-}" in
stable)
	latest_stable
	;;
testing)
	latest_testing
	;;
-h | --help)
	show_help
	;;
*)
	show_help >&2
	exit 1
	;;
esac
