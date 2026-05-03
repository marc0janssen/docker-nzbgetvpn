#!/bin/sh

set -eu

# Name: docker-nzbgetvpn
# Coder: Marco Janssen (micro.blog @marc0janssen https://micro.mjanssen.nl)
# date: 2021-11-28 14:24:26
# update: 2021-11-28 14:24:32

show_help() {
	cat <<EOF
Usage: $0 [nzbget-version|newest] [--base <tag|newest>]

Build the stable NZBGetVPN Docker image.

Without an argument, this builds with the version and SHA256 values already
stored in Dockerfile.

With a version argument, this first runs scripts/update-stable.sh to update
Dockerfile, README.md, and SHA256 values, then builds the image.

Use "newest" to look up the latest stable NZBGet GitHub release before
updating and building.

Use "--base newest" to look up and pin the newest numeric
binhex/arch-int-vpn Docker Hub tag before building.

Examples:
  $0
  $0 26.2
  $0 newest
  $0 --base newest
  $0 newest --base newest
EOF
}

case "${1:-}" in
	-h|--help)
		show_help
		exit 0
		;;
esac

NZBGET_VERSION_ARG=""
BASE_IMAGE_ARG=""

while [ "$#" -gt 0 ]; do
	case "$1" in
		--base)
			if [ "$#" -lt 2 ]; then
				echo "--base requires a value" >&2
				exit 1
			fi
			BASE_IMAGE_ARG="$2"
			shift 2
			;;
		--base=*)
			BASE_IMAGE_ARG="${1#--base=}"
			shift
			;;
		-*)
			show_help >&2
			exit 1
			;;
		*)
			if [ -n "${NZBGET_VERSION_ARG}" ]; then
				show_help >&2
				exit 1
			fi
			NZBGET_VERSION_ARG="$1"
			shift
			;;
	esac
done

if [ -n "${BASE_IMAGE_ARG}" ]; then
	./scripts/update-base-image.sh ./Dockerfile "${BASE_IMAGE_ARG}"
fi

if [ -n "${NZBGET_VERSION_ARG}" ]; then
	# Update Dockerfile, README, and SHA256 values only when a new version is supplied.
	if [ "${NZBGET_VERSION_ARG}" = "newest" ]; then
		VERSION_TO_UPDATE="$(./scripts/latest-nzbget-version.sh stable)"
		echo "[info] Latest stable NZBGet version is ${VERSION_TO_UPDATE}"
	else
		VERSION_TO_UPDATE="${NZBGET_VERSION_ARG}"
	fi
	./scripts/update-stable.sh "${VERSION_TO_UPDATE}"
fi

VERSION=$(sed -n 's/^ENV NZBGET_VERSION=//p' ./Dockerfile)
if [ -z "${VERSION}" ]; then
	echo "Unable to read NZBGET_VERSION from Dockerfile" >&2
	exit 1
fi

docker buildx build --no-cache --platform linux/amd64 --push -t marc0janssen/nzbgetvpn:${VERSION} -t marc0janssen/nzbgetvpn:stable -f ./Dockerfile .

docker pushrm marc0janssen/nzbgetvpn:stable
