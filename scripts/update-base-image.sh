#!/bin/sh

set -eu

show_help() {
	cat <<EOF
Usage: $0 <Dockerfile> <tag|newest>

Update the binhex/arch-int-vpn base image tag in a Dockerfile.

Examples:
  $0 Dockerfile newest
  $0 Dockerfile-testing 2026032801
EOF
}

sed_in_place() {
	expression="$1"
	file="$2"

	if sed -i '' "${expression}" "${file}" 2>/dev/null; then
		return
	fi

	sed -i "${expression}" "${file}"
}

if [ "$#" -ne 2 ]; then
	show_help >&2
	exit 1
fi

dockerfile="$1"
tag="$2"

if [ ! -f "${dockerfile}" ]; then
	echo "Dockerfile '${dockerfile}' does not exist" >&2
	exit 1
fi

if [ "${tag}" = "newest" ]; then
	tag="$(./scripts/latest-binhex-base-tag.sh)"
	echo "[info] Latest binhex/arch-int-vpn tag is ${tag}"
fi

case "${tag}" in
	""|*[!0-9]*)
		echo "Base image tag '${tag}' is invalid; expected a numeric tag like 2026032801" >&2
		exit 1
		;;
esac

sed_in_place "s|^FROM binhex/arch-int-vpn:.*|FROM binhex/arch-int-vpn:${tag}|" "${dockerfile}"

echo "[info] Updated ${dockerfile} base image to binhex/arch-int-vpn:${tag}"
