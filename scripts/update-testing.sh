#!/bin/sh

set -eu

REPO_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DOCKERFILE="${REPO_DIR}/Dockerfile-testing"
README="${REPO_DIR}/README.md"
CONTAINER_README="${REPO_DIR}/README-containers.md"
TMP_DIR="${TMPDIR:-/tmp}"
EXPECTED_SHA256=""
ACCEPT_DOWNLOADED_SHA256="no"

CURRENT_VERSION="$(sed -n 's/^ENV NZBGET_VERSION=//p' "${DOCKERFILE}")"
VERSION="${CURRENT_VERSION}"
VERSION_DIR="testing"
NZBGET_URL="https://github.com/nzbgetcom/nzbget/releases/download/${VERSION_DIR}/nzbget-${VERSION}-bin-linux.run"
NZBGET_TMP=""

show_help() {
	cat <<EOF
Usage: $0 [version] --sha256 <expected-sha256>
       $0 [version] --accept-downloaded-sha256

Update testing Dockerfile and README NZBGet values.

Prefer --sha256 with an independently verified checksum. Use
--accept-downloaded-sha256 only when intentionally pinning the checksum
calculated from the downloaded artifact.
EOF
}

cleanup() {
	if [ -n "${NZBGET_TMP}" ] && [ -f "${NZBGET_TMP}" ]; then
		rm -f "${NZBGET_TMP}"
	fi
}

trap cleanup EXIT

sed_in_place() {
	expression="$1"
	file="$2"

	if sed -i '' "${expression}" "${file}" 2>/dev/null; then
		return
	fi

	sed -i "${expression}" "${file}"
}

sha256_file() {
	file="$1"

	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "${file}" | awk '{print $1}'
	else
		shasum -a 256 "${file}" | awk '{print $1}'
	fi
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

is_release_version() {
	printf '%s\n' "$1" | grep -Eq '^[A-Za-z0-9_.-]+$'
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	-h | --help)
		show_help
		exit 0
		;;
	--sha256)
		if [ "$#" -lt 2 ]; then
			echo "--sha256 requires a value" >&2
			exit 1
		fi
		EXPECTED_SHA256="$2"
		shift 2
		;;
	--sha256=*)
		EXPECTED_SHA256="${1#--sha256=}"
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
		if [ "${VERSION}" != "${CURRENT_VERSION}" ]; then
			show_help >&2
			exit 1
		fi
		VERSION="$1"
		shift
		;;
	esac
done

if ! is_release_version "${VERSION}"; then
	echo "NZBGet testing version '${VERSION}' contains invalid characters" >&2
	exit 1
fi

if [ -n "${EXPECTED_SHA256}" ] && ! is_sha256 "${EXPECTED_SHA256}"; then
	echo "--sha256 must be a 64-character hexadecimal SHA256 value" >&2
	exit 1
fi

if [ -n "${EXPECTED_SHA256}" ] && is_truthy "${ACCEPT_DOWNLOADED_SHA256}"; then
	echo "Use either --sha256 or --accept-downloaded-sha256, not both" >&2
	exit 1
fi

VERSION_DIR="testing"
NZBGET_URL="https://github.com/nzbgetcom/nzbget/releases/download/${VERSION_DIR}/nzbget-${VERSION}-bin-linux.run"
NZBGET_TMP="${TMP_DIR%/}/nzbget-${VERSION}-bin-linux.run.$$"

echo "[info] Downloading NZBGet testing ${VERSION}..."
curl -L --fail --silent --show-error -o "${NZBGET_TMP}" "${NZBGET_URL}"
NZBGET_SHA256="$(sha256_file "${NZBGET_TMP}")"

if [ -n "${EXPECTED_SHA256}" ]; then
	if [ "$(printf '%s\n' "${NZBGET_SHA256}" | tr 'A-F' 'a-f')" != "$(printf '%s\n' "${EXPECTED_SHA256}" | tr 'A-F' 'a-f')" ]; then
		echo "Downloaded artifact checksum does not match --sha256" >&2
		echo "Expected: ${EXPECTED_SHA256}" >&2
		echo "Actual:   ${NZBGET_SHA256}" >&2
		exit 1
	fi
elif ! is_truthy "${ACCEPT_DOWNLOADED_SHA256}"; then
	echo "Refusing to pin checksum without verification." >&2
	echo "Downloaded SHA256: ${NZBGET_SHA256}" >&2
	echo "Re-run with --sha256 <expected-sha256>, or --accept-downloaded-sha256 if you intentionally accept this artifact." >&2
	exit 1
fi

sed_in_place "s/^ENV NZBGET_VERSION=.*/ENV NZBGET_VERSION=${VERSION}/" "${DOCKERFILE}"
sed_in_place "s/^ENV NZBGET_VERSION_DIR=.*/ENV NZBGET_VERSION_DIR=${VERSION_DIR}/" "${DOCKERFILE}"
sed_in_place "s/^ENV NZBGET_SHA256=.*/ENV NZBGET_SHA256=${NZBGET_SHA256}/" "${DOCKERFILE}"
sed_in_place "s/^\\* NZBGET Current testing version: .*/\\* NZBGET Current testing version: ${VERSION}/" "${README}"
if [ -f "${CONTAINER_README}" ]; then
	sed_in_place "s/^\\* NZBGET Current testing version: .*/\\* NZBGET Current testing version: ${VERSION}/" "${CONTAINER_README}"
fi

echo "[info] Updated ${DOCKERFILE}"
echo "[info] NZBGET_SHA256=${NZBGET_SHA256}"
