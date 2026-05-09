#!/bin/sh

set -eu

REPO_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION_FILE="${REPO_DIR}/VERSION"
README="${REPO_DIR}/README.md"
CONTAINER_README="${REPO_DIR}/README-containers.md"
CHANGELOG_FILE="${REPO_DIR}/CHANGELOG.md"
BUMPED_FROM=""
BUMPED_TO=""

show_help() {
	cat <<EOF
Usage: $0 <Dockerfile> <tag|newest>

Update the binhex/arch-int-vpn base image tag in a Dockerfile.

When <tag> is "newest" and the resolved tag differs from the current
Dockerfile tag, bump the NZBGetVPN image/codebase VERSION patch value.

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

is_semver() {
	printf '%s\n' "$1" | grep -Eq '^[0-9]+[.][0-9]+[.][0-9]+$'
}

bump_patch_version() {
	current_version="$(sed -n '1{s/^[[:space:]]*//;s/[[:space:]]*$//;p;}' "${VERSION_FILE}")"

	if ! is_semver "${current_version}"; then
		echo "VERSION must contain a semver value like 1.0.0" >&2
		exit 1
	fi

	IFS=. read -r major minor patch <<EOF_VERSION
${current_version}
EOF_VERSION
	new_version="${major}.${minor}.$((patch + 1))"
	BUMPED_FROM="${current_version}"
	BUMPED_TO="${new_version}"

	printf '%s\n' "${new_version}" >"${VERSION_FILE}"
	sed_in_place "s|^\\* NZBGetVPN image/codebase version: .*|* NZBGetVPN image/codebase version: ${new_version}|" "${README}"
	if [ -f "${CONTAINER_README}" ]; then
		sed_in_place "s|^\\* NZBGetVPN image/codebase version: .*|* NZBGetVPN image/codebase version: ${new_version}|" "${CONTAINER_README}"
	fi

	echo "[info] Bumped NZBGetVPN image/codebase version from ${current_version} to ${new_version}"
}

insert_changelog_entry_for_base_bump() {
	dockerfile_path="$1"
	old_tag="$2"
	new_tag="$3"
	today="$(date +%Y-%m-%d)"
	dockerfile_name="$(basename -- "${dockerfile_path}")"
	tmp_file="$(mktemp)"

	if [ ! -f "${CHANGELOG_FILE}" ]; then
		echo "[warn] ${CHANGELOG_FILE} not found; skipping changelog update" >&2
		return 0
	fi
	if [ -z "${BUMPED_TO}" ]; then
		echo "[warn] Missing bumped version; skipping changelog update" >&2
		return 0
	fi
	if grep -q "^## \[${BUMPED_TO}\] - " "${CHANGELOG_FILE}"; then
		echo "[info] Changelog already contains ${BUMPED_TO}; skipping automatic changelog insert"
		return 0
	fi

	awk -v version="${BUMPED_TO}" -v date_value="${today}" -v file_name="${dockerfile_name}" -v old_value="${old_tag}" -v new_value="${new_tag}" '
BEGIN { inserted=0 }
{
	print $0
	if (!inserted && $0 ~ /^This project uses semantic versioning/) {
		print ""
		print "## [" version "] - " date_value
		print ""
		print "### Changed"
		print ""
		print "- Updated " file_name " base image tag from `binhex/arch-int-vpn:" old_value "` to `binhex/arch-int-vpn:" new_value "` via `--base newest`."
		print "- Automatically bumped version metadata in `VERSION`, `README.md`, and `README-containers.md`."
		print ""
		inserted=1
	}
}
' "${CHANGELOG_FILE}" >"${tmp_file}"

	cp "${tmp_file}" "${CHANGELOG_FILE}"
	rm -f "${tmp_file}"
	echo "[info] Added changelog entry for version ${BUMPED_TO}"
}

case "${1:-}" in
-h | --help)
	show_help
	exit 0
	;;
esac

if [ "$#" -ne 2 ]; then
	show_help >&2
	exit 1
fi

dockerfile="$1"
requested_tag="$2"
tag="${requested_tag}"

if [ ! -f "${dockerfile}" ]; then
	echo "Dockerfile '${dockerfile}' does not exist" >&2
	exit 1
fi

current_tag="$(sed -n 's|^ARG BASE_IMAGE_TAG=||p' "${dockerfile}")"
if [ -z "${current_tag}" ]; then
	echo "Unable to read current BASE_IMAGE_TAG from '${dockerfile}'" >&2
	exit 1
fi

if [ "${requested_tag}" = "newest" ]; then
	tag="$("${REPO_DIR}/scripts/latest-binhex-base-tag.sh")"
	echo "[info] Latest binhex/arch-int-vpn tag is ${tag}"
fi

case "${tag}" in
"" | *[!0-9]*)
	echo "Base image tag '${tag}' is invalid; expected a numeric tag like 2026032801" >&2
	exit 1
	;;
esac

sed_in_place "s|^ARG BASE_IMAGE_TAG=.*|ARG BASE_IMAGE_TAG=${tag}|" "${dockerfile}"

echo "[info] Updated ${dockerfile} base image to binhex/arch-int-vpn:${tag}"

if [ "${requested_tag}" = "newest" ] && [ "${current_tag}" != "${tag}" ]; then
	bump_patch_version
	insert_changelog_entry_for_base_bump "${dockerfile}" "${current_tag}" "${tag}"
elif [ "${requested_tag}" = "newest" ]; then
	echo "[info] Base image tag is already ${tag}; VERSION not bumped"
fi
