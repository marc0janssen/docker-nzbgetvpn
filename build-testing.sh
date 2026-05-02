#!/bin/sh

set -eu

# Name: docker-nzbgetvpn
# Coder: Marco Janssen (micro.blog @marc0janssen https://micro.mjanssen.nl)
# date: 2021-11-28 14:24:26
# update: 2021-11-28 14:24:32

show_help() {
	cat <<EOF
Usage: $0 [nzbget-testing-version]

Build the testing NZBGetVPN Docker image.

Without an argument, this builds with the version and SHA256 values already
stored in Dockerfile-testing.

With a version argument, this first runs scripts/update-testing.sh to update
Dockerfile-testing, README.md, and SHA256 values, then builds the image.

Examples:
  $0
  $0 26.2-testing-20260510
EOF
}

case "${1:-}" in
	-h|--help)
		show_help
		exit 0
		;;
esac

if [ "$#" -gt 1 ]; then
	show_help >&2
	exit 1
fi

if [ "$#" -eq 1 ]; then
	# Update Dockerfile-testing, README, and SHA256 values only when a new version is supplied.
	./scripts/update-testing.sh "$1"
fi

VERSION=$(sed -n 's/^ENV NZBGET_VERSION=//p' ./Dockerfile-testing)
if [ -z "${VERSION}" ]; then
	echo "Unable to read NZBGET_VERSION from Dockerfile-testing" >&2
	exit 1
fi

docker buildx build --no-cache --platform linux/amd64 --push -t marc0janssen/nzbgetvpn:${VERSION} -t marc0janssen/nzbgetvpn:testing -f ./Dockerfile-testing .

docker pushrm marc0janssen/nzbgetvpn:testing
