#!/bin/sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
lib_path="${repo_root}/data/scripts/lib.sh"
doc_path="${repo_root}/data/scripts/docs/rotate_on_poor_speed.md"
mode="${1:-write}"

if [ ! -r "${lib_path}" ]; then
	echo "[crit] Missing shared library: ${lib_path}" >&2
	exit 1
fi

if [ ! -f "${doc_path}" ]; then
	echo "[crit] Missing rotate doc: ${doc_path}" >&2
	exit 1
fi

generated_defaults="$(mktemp)"
generated_doc="$(mktemp)"
trap 'rm -f "${generated_defaults}" "${generated_doc}"' EXIT INT TERM

bash -c ". \"${lib_path}\"; nzbgetvpn_print_rotate_defaults" >"${generated_defaults}"

awk -v defaults_file="${generated_defaults}" '
BEGIN {
	in_block = 0
}
{
	if ($0 == "<!-- BEGIN ROTATE_DEFAULTS -->") {
		print $0
		print ""
		print "```text"
		while ((getline line < defaults_file) > 0) {
			print line
		}
		close(defaults_file)
		print "```"
		in_block = 1
		next
	}
	if ($0 == "<!-- END ROTATE_DEFAULTS -->") {
		in_block = 0
		print $0
		next
	}
	if (in_block == 0) {
		print $0
	}
}
' "${doc_path}" >"${generated_doc}"

case "${mode}" in
check)
	if cmp -s "${doc_path}" "${generated_doc}"; then
		echo "[info] rotate defaults doc is up to date"
		exit 0
	fi
	echo "[crit] rotate defaults doc is outdated; run ./scripts/sync-rotate-defaults-doc.sh" >&2
	exit 1
	;;
write)
	cp "${generated_doc}" "${doc_path}"
	echo "[info] Updated ${doc_path}"
	;;
*)
	echo "[crit] Unsupported mode '${mode}' (use: write|check)" >&2
	exit 1
	;;
esac
