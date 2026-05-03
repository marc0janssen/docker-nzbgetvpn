#!/bin/sh

set -eu

DOCKERHUB_TAGS_URL="https://hub.docker.com/v2/repositories/binhex/arch-int-vpn/tags?page_size=100&ordering=last_updated"

show_help() {
	cat <<EOF
Usage: $0

Print the newest numeric binhex/arch-int-vpn Docker Hub tag.
EOF
}

case "${1:-}" in
	-h|--help)
		show_help
		exit 0
		;;
	"")
		;;
	*)
		show_help >&2
		exit 1
		;;
esac

response="$(curl -L --fail --silent --show-error "${DOCKERHUB_TAGS_URL}")"
tag="$(printf '%s\n' "${response}" \
	| tr ',' '\n' \
	| sed -n 's/.*"name":"\([0-9][0-9]*\)".*/\1/p' \
	| head -n 1)"

if [ -z "${tag}" ]; then
	echo "Unable to determine latest numeric binhex/arch-int-vpn tag" >&2
	exit 1
fi

printf '%s\n' "${tag}"
