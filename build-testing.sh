#!/bin/sh

set -eu

# Name: docker-nzbgetvpn
# Coder: Marco Janssen (micro.blog @marc0janssen https://micro.mjanssen.nl)
# date: 2021-11-28 14:24:26
# update: 2021-11-28 14:24:32

show_help() {
	cat <<EOF
Usage: $0 [nzbget-testing-version|newest] [--base <tag|newest>]
       $0 [nzbget-testing-version|newest] --sha256 <expected-sha256> [--base <tag|newest>]
       $0 [nzbget-testing-version|newest] --accept-downloaded-sha256 [--base <tag|newest>]

Build the testing NZBGetVPN Docker image.

Without an argument, this builds with the version and SHA256 values already
stored in Dockerfile-testing.

The image codebase version is read from VERSION and pushed as an additional
Docker tag in the form "<nzbget-testing-version>-image-v<version>".

With a version argument, this first runs scripts/update-testing.sh to update
Dockerfile-testing, README.md, and SHA256 values, then builds the image.

When updating NZBGet, pass --sha256 with an independently verified checksum.
Use --accept-downloaded-sha256 only when you intentionally accept the checksum
calculated from the downloaded release artifact.

Use "newest" to look up the current testing NZBGet GitHub release asset before
updating and building.

Use "--base newest" to look up and pin the newest numeric
binhex/arch-int-vpn Docker Hub tag before building. If that changes the
Dockerfile-testing base tag, VERSION is bumped by one patch version.

Examples:
  $0
  $0 26.2-testing-20260510 --sha256 <expected-sha256>
  $0 newest --accept-downloaded-sha256
  $0 --base newest
  $0 newest --accept-downloaded-sha256 --base newest
EOF
}

is_sha256() {
	printf '%s\n' "$1" | grep -Eq '^[0-9a-fA-F]{64}$'
}

is_truthy() {
	case "$1" in
	yes | true | 1)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

is_semver() {
	printf '%s\n' "$1" | grep -Eq '^[0-9]+[.][0-9]+[.][0-9]+$'
}

is_docker_tag() {
	tag="$1"

	[ -n "${tag}" ] || return 1
	[ "${#tag}" -le 128 ] || return 1
	printf '%s\n' "${tag}" | grep -Eq '^[A-Za-z0-9_][A-Za-z0-9_.-]*$'
}

trim_value() {
	printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

case "${1:-}" in
-h | --help)
	show_help
	exit 0
	;;
esac

NZBGET_VERSION_ARG=""
BASE_IMAGE_ARG=""
EXPECTED_SHA256_ARG=""
ACCEPT_DOWNLOADED_SHA256="no"

while [ "$#" -gt 0 ]; do
	arg="$(trim_value "$1")"
	case "$1" in
	--base)
		if [ "$#" -lt 2 ]; then
			echo "--base requires a value" >&2
			exit 1
		fi
		BASE_IMAGE_ARG="$(trim_value "$2")"
		shift 2
		;;
	--base=*)
		BASE_IMAGE_ARG="$(trim_value "${arg#--base=}")"
		shift
		;;
	--sha256)
		if [ "$#" -lt 2 ]; then
			echo "--sha256 requires a value" >&2
			exit 1
		fi
		EXPECTED_SHA256_ARG="$(trim_value "$2")"
		shift 2
		;;
	--sha256=*)
		EXPECTED_SHA256_ARG="$(trim_value "${arg#--sha256=}")"
		shift
		;;
	--accept-downloaded-sha256)
		ACCEPT_DOWNLOADED_SHA256="yes"
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
		NZBGET_VERSION_ARG="$(trim_value "${arg}")"
		shift
		;;
	esac
done

if [ -n "${EXPECTED_SHA256_ARG}" ] && ! is_sha256 "${EXPECTED_SHA256_ARG}"; then
	echo "--sha256 must be a 64-character hexadecimal SHA256 value" >&2
	exit 1
fi

if [ -n "${EXPECTED_SHA256_ARG}" ] && is_truthy "${ACCEPT_DOWNLOADED_SHA256}"; then
	echo "Use either --sha256 or --accept-downloaded-sha256, not both" >&2
	exit 1
fi

if [ -z "${NZBGET_VERSION_ARG}" ] && { [ -n "${EXPECTED_SHA256_ARG}" ] || is_truthy "${ACCEPT_DOWNLOADED_SHA256}"; }; then
	echo "--sha256 and --accept-downloaded-sha256 are only valid when updating an NZBGet version" >&2
	exit 1
fi

if [ -n "${NZBGET_VERSION_ARG}" ] && [ -z "${EXPECTED_SHA256_ARG}" ] && ! is_truthy "${ACCEPT_DOWNLOADED_SHA256}"; then
	echo "Updating NZBGet requires --sha256 <expected-sha256> or --accept-downloaded-sha256" >&2
	exit 1
fi

if [ -n "${BASE_IMAGE_ARG}" ]; then
	./scripts/update-base-image.sh ./Dockerfile-testing "${BASE_IMAGE_ARG}"
fi

if [ -n "${NZBGET_VERSION_ARG}" ]; then
	# Update Dockerfile-testing, README, and SHA256 values only when a new version is supplied.
	if [ "${NZBGET_VERSION_ARG}" = "newest" ]; then
		VERSION_TO_UPDATE="$(./scripts/latest-nzbget-version.sh testing)"
		echo "[info] Latest testing NZBGet version is ${VERSION_TO_UPDATE}"
	else
		VERSION_TO_UPDATE="${NZBGET_VERSION_ARG}"
	fi
	if [ -n "${EXPECTED_SHA256_ARG}" ]; then
		./scripts/update-testing.sh "${VERSION_TO_UPDATE}" --sha256 "${EXPECTED_SHA256_ARG}"
	elif is_truthy "${ACCEPT_DOWNLOADED_SHA256}"; then
		./scripts/update-testing.sh "${VERSION_TO_UPDATE}" --accept-downloaded-sha256
	else
		./scripts/update-testing.sh "${VERSION_TO_UPDATE}"
	fi
fi

VERSION=$(sed -n 's/^ENV NZBGET_VERSION=//p' ./Dockerfile-testing)
if [ -z "${VERSION}" ]; then
	echo "Unable to read NZBGET_VERSION from Dockerfile-testing" >&2
	exit 1
fi

IMAGE_VERSION=$(sed -n '1{s/^[[:space:]]*//;s/[[:space:]]*$//;p;}' ./VERSION)
if ! is_semver "${IMAGE_VERSION}"; then
	echo "VERSION must contain a semver value like 1.0.0" >&2
	exit 1
fi

if ! is_docker_tag "${VERSION}" || ! is_docker_tag "${VERSION}-image-v${IMAGE_VERSION}"; then
	echo "Docker tag values contain invalid characters" >&2
	exit 1
fi

docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push --build-arg "NZBGETVPN_VERSION=${IMAGE_VERSION}" -t "marc0janssen/nzbgetvpn:${VERSION}" -t "marc0janssen/nzbgetvpn:${VERSION}-image-v${IMAGE_VERSION}" -t "marc0janssen/nzbgetvpn:testing" -f ./Dockerfile-testing .

docker pushrm --file README-containers.md marc0janssen/nzbgetvpn:testing
