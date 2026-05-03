#!/bin/sh

set -eu

REPO_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DOCKERFILE="${REPO_DIR}/Dockerfile"
README="${REPO_DIR}/README.md"
CONTAINER_README="${REPO_DIR}/README-containers.md"
TMP_DIR="${TMPDIR:-/tmp}"

CURRENT_VERSION="$(sed -n 's/^ENV NZBGET_VERSION=//p' "${DOCKERFILE}")"
VERSION="${1:-${CURRENT_VERSION}}"
VERSION_DIR="v${VERSION}"
NZBGET_URL="https://github.com/nzbgetcom/nzbget/releases/download/${VERSION_DIR}/nzbget-${VERSION}-bin-linux.run"
NZBGET_TMP="${TMP_DIR}/nzbget-${VERSION}-bin-linux.run"

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

echo "[info] Downloading NZBGet ${VERSION}..."
curl -L --fail --silent --show-error -o "${NZBGET_TMP}" "${NZBGET_URL}"
NZBGET_SHA256="$(sha256_file "${NZBGET_TMP}")"

sed_in_place "s/^ENV NZBGET_VERSION=.*/ENV NZBGET_VERSION=${VERSION}/" "${DOCKERFILE}"
sed_in_place "s/^ENV NZBGET_VERSION_DIR=.*/ENV NZBGET_VERSION_DIR=${VERSION_DIR}/" "${DOCKERFILE}"
sed_in_place "s/^ENV NZBGET_SHA256=.*/ENV NZBGET_SHA256=${NZBGET_SHA256}/" "${DOCKERFILE}"
sed_in_place "s/^\\* NZBGET Current stable version: .*/\\* NZBGET Current stable version: ${VERSION}/" "${README}"
if [ -f "${CONTAINER_README}" ]; then
	sed_in_place "s/^\\* NZBGET Current stable version: .*/\\* NZBGET Current stable version: ${VERSION}/" "${CONTAINER_README}"
fi

echo "[info] Updated ${DOCKERFILE}"
echo "[info] NZBGET_SHA256=${NZBGET_SHA256}"
