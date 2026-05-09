#!/bin/sh

set -eu

show_help() {
	cat <<EOF
Usage: $0 [nzbget-testing-version|newest] [--base <tag|newest>] [--repo <registry/repository>] [--platform <platforms>]
       $0 [nzbget-testing-version|newest] --sha256 <expected-sha256> [--base <tag|newest>] [--repo <registry/repository>] [--platform <platforms>]
       $0 [nzbget-testing-version|newest] --accept-downloaded-sha256 [--base <tag|newest>] [--repo <registry/repository>] [--platform <platforms>]

Local/private-registry variant of build-testing.sh.

Without an argument, this builds with values already pinned in Dockerfile-testing.
With a version argument, this first runs scripts/update-testing.sh.

Defaults:
  repo:     192.168.1.1:5000/nzbgetvpn (from env LOCAL_REPO or build-testing-local.env)
  platform: linux/amd64 (from env LOCAL_PLATFORM or build-testing-local.env)
  tags:     <nzbget-version>, <nzbget-version>-image-v<version>, testing

Optional env file:
  build-testing-local.env next to this script (gitignored; copy from build-testing-local.env.example).
  Command-line --repo and --platform override these values.

Examples:
  $0
  $0 newest --accept-downloaded-sha256
  $0 --base newest
  $0 --repo 192.168.1.1:5000/nzbgetvpn --platform linux/amd64,linux/arm64
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

# Defaults; overridden by build-testing-local.env unless LOCAL_REPO / LOCAL_PLATFORM were already exported,
# then by CLI --repo / --platform.
LOCAL_REPO_ARG="192.168.1.1:5000/nzbgetvpn"
PLATFORM_ARG="linux/amd64"

# If the caller already exported LOCAL_REPO / LOCAL_PLATFORM, remember them so we can
# restore after sourcing build-testing-local.env (file must not clobber the shell).
_prior_repo_set=0
_prior_plat_set=0
_saved_repo=""
_saved_plat=""
case ${LOCAL_REPO+x} in x)
	_saved_repo="${LOCAL_REPO}"
	_prior_repo_set=1
	;;
esac
case ${LOCAL_PLATFORM+x} in x)
	_saved_plat="${LOCAL_PLATFORM}"
	_prior_plat_set=1
	;;
esac

_script_dir="$(CDPATH= cd "$(dirname "$0")" && pwd)"
_env_file="${_script_dir}/build-testing-local.env"
if [ -f "${_env_file}" ]; then
	# shellcheck disable=SC1090
	. "${_env_file}"
fi

if [ "${_prior_repo_set}" -eq 1 ]; then
	LOCAL_REPO="${_saved_repo}"
fi
if [ "${_prior_plat_set}" -eq 1 ]; then
	LOCAL_PLATFORM="${_saved_plat}"
fi

LOCAL_REPO_ARG="${LOCAL_REPO:-${LOCAL_REPO_ARG}}"
PLATFORM_ARG="${LOCAL_PLATFORM:-${PLATFORM_ARG}}"

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
	--repo)
		if [ "$#" -lt 2 ]; then
			echo "--repo requires a value" >&2
			exit 1
		fi
		LOCAL_REPO_ARG="$(trim_value "$2")"
		shift 2
		;;
	--repo=*)
		LOCAL_REPO_ARG="$(trim_value "${arg#--repo=}")"
		shift
		;;
	--platform)
		if [ "$#" -lt 2 ]; then
			echo "--platform requires a value" >&2
			exit 1
		fi
		PLATFORM_ARG="$(trim_value "$2")"
		shift 2
		;;
	--platform=*)
		PLATFORM_ARG="$(trim_value "${arg#--platform=}")"
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

if [ -z "${LOCAL_REPO_ARG}" ]; then
	echo "--repo must not be empty" >&2
	exit 1
fi

if [ -z "${PLATFORM_ARG}" ]; then
	echo "--platform must not be empty" >&2
	exit 1
fi

if [ -n "${BASE_IMAGE_ARG}" ]; then
	./scripts/update-base-image.sh ./Dockerfile-testing "${BASE_IMAGE_ARG}"
fi

if [ -n "${NZBGET_VERSION_ARG}" ]; then
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

if ! is_docker_tag "${VERSION}" || ! is_docker_tag "${VERSION}-image-v${IMAGE_VERSION}" || ! is_docker_tag "testing"; then
	echo "Docker tag values contain invalid characters" >&2
	exit 1
fi

docker buildx build --no-cache --platform "${PLATFORM_ARG}" --push \
	--build-arg "NZBGETVPN_VERSION=${IMAGE_VERSION}" \
	-t "${LOCAL_REPO_ARG}:${VERSION}" \
	-t "${LOCAL_REPO_ARG}:${VERSION}-image-v${IMAGE_VERSION}" \
	-t "${LOCAL_REPO_ARG}:testing" \
	-f ./Dockerfile-testing .
