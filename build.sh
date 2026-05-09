#!/bin/sh

set -eu

# Name: docker-nzbgetvpn
# Coder: Marco Janssen (micro.blog @marc0janssen https://micro.mjanssen.nl)
# date: 2021-11-28 14:24:26
# update: 2021-11-28 14:24:32

show_help() {
	cat <<EOF
Usage: $0 [nzbget-version|newest] [--base <tag|newest>] [--docker-repo <namespace/name>] [--platform <platforms>]
       $0 [nzbget-version|newest] --sha256 <expected-sha256> [--base <tag|newest>] [--docker-repo <namespace/name>] [--platform <platforms>]
       $0 [nzbget-version|newest] --accept-downloaded-sha256 [--base <tag|newest>] [--docker-repo <namespace/name>] [--platform <platforms>]

Build the stable NZBGetVPN Docker image.

Without an argument, this builds with the version and SHA256 values already
stored in Dockerfile.

The image codebase version is read from VERSION and pushed as an additional
Docker tag in the form "<nzbget-version>-image-v<version>".

With a version argument, this first runs scripts/update-stable.sh to update
Dockerfile, README.md, and SHA256 values, then builds the image.

When updating NZBGet, pass --sha256 with an independently verified checksum.
Use --accept-downloaded-sha256 only when you intentionally accept the checksum
calculated from the downloaded release artifact.

Use "newest" to look up the latest stable NZBGet GitHub release before
updating and building.

Optional env file build.env (copy from build.env.example): DOCKER_IMAGE_REPO,
BUILD_PLATFORM. Same precedence as build-testing-local.env (defaults, file,
exported vars).

Use "--base newest" to look up and pin the newest numeric
binhex/arch-int-vpn Docker Hub tag before building. If that changes the
Dockerfile base tag, VERSION is bumped by one patch version.

Optional docker overrides (highest precedence): --docker-repo, --platform (see build.env).

Examples:
  $0
  $0 26.2 --sha256 <expected-sha256>
  $0 newest --accept-downloaded-sha256
  $0 --base newest
  $0 newest --accept-downloaded-sha256 --base newest
  $0 --docker-repo otheruser/nzbgetvpn --platform linux/amd64
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
CLI_DOCKER_REPO_ARG=""
CLI_PLATFORM_ARG=""

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
	--docker-repo)
		if [ "$#" -lt 2 ]; then
			echo "--docker-repo requires a value" >&2
			exit 1
		fi
		CLI_DOCKER_REPO_ARG="$(trim_value "$2")"
		shift 2
		;;
	--docker-repo=*)
		CLI_DOCKER_REPO_ARG="$(trim_value "${arg#--docker-repo=}")"
		shift
		;;
	--platform)
		if [ "$#" -lt 2 ]; then
			echo "--platform requires a value" >&2
			exit 1
		fi
		CLI_PLATFORM_ARG="$(trim_value "$2")"
		shift 2
		;;
	--platform=*)
		CLI_PLATFORM_ARG="$(trim_value "${arg#--platform=}")"
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
	if [ -n "${EXPECTED_SHA256_ARG}" ]; then
		./scripts/update-stable.sh "${VERSION_TO_UPDATE}" --sha256 "${EXPECTED_SHA256_ARG}"
	elif is_truthy "${ACCEPT_DOWNLOADED_SHA256}"; then
		./scripts/update-stable.sh "${VERSION_TO_UPDATE}" --accept-downloaded-sha256
	else
		./scripts/update-stable.sh "${VERSION_TO_UPDATE}"
	fi
fi

VERSION=$(sed -n 's/^ENV NZBGET_VERSION=//p' ./Dockerfile)
if [ -z "${VERSION}" ]; then
	echo "Unable to read NZBGET_VERSION from Dockerfile" >&2
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

DOCKER_IMAGE_REPO_DEFAULT="marc0janssen/nzbgetvpn"
BUILD_PLATFORM_DEFAULT="linux/amd64,linux/arm64"

_prior_docker_repo_set=0
_prior_plat_set=0
_saved_docker_repo=""
_saved_plat=""
case ${DOCKER_IMAGE_REPO+x} in x)
	_saved_docker_repo="${DOCKER_IMAGE_REPO}"
	_prior_docker_repo_set=1
	;;
esac
case ${BUILD_PLATFORM+x} in x)
	_saved_plat="${BUILD_PLATFORM}"
	_prior_plat_set=1
	;;
esac

_script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
_env_file="${_script_dir}/build.env"
if [ -f "${_env_file}" ]; then
	# shellcheck disable=SC1090
	. "${_env_file}"
fi
if [ "${_prior_docker_repo_set}" -eq 1 ]; then
	DOCKER_IMAGE_REPO="${_saved_docker_repo}"
fi
if [ "${_prior_plat_set}" -eq 1 ]; then
	BUILD_PLATFORM="${_saved_plat}"
fi

DOCKER_IMAGE_REPO="${DOCKER_IMAGE_REPO:-${DOCKER_IMAGE_REPO_DEFAULT}}"
BUILD_PLATFORM="${BUILD_PLATFORM:-${BUILD_PLATFORM_DEFAULT}}"

if [ -n "${CLI_DOCKER_REPO_ARG}" ]; then
	DOCKER_IMAGE_REPO="${CLI_DOCKER_REPO_ARG}"
fi
if [ -n "${CLI_PLATFORM_ARG}" ]; then
	BUILD_PLATFORM="${CLI_PLATFORM_ARG}"
fi

docker buildx build --no-cache --platform "${BUILD_PLATFORM}" --push --build-arg "NZBGETVPN_VERSION=${IMAGE_VERSION}" -t "${DOCKER_IMAGE_REPO}:${VERSION}" -t "${DOCKER_IMAGE_REPO}:${VERSION}-image-v${IMAGE_VERSION}" -t "${DOCKER_IMAGE_REPO}:stable" -f ./Dockerfile .

docker pushrm --file README-containers.md "${DOCKER_IMAGE_REPO}:stable"
