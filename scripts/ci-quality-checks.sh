#!/bin/sh
set -eu

log_info() {
	echo "[info] [quality] $*"
}

log_crit() {
	echo "[crit] [quality] $*" >&2
}

require_cmd() {
	cmd="$1"
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		log_crit "Missing required command: ${cmd}"
		exit 1
	fi
}

main() {
	file_list="$(mktemp)"
	trap 'rm -f "${file_list}"' EXIT INT TERM
	default_shellcheck_excludes="SC1007,SC1091,SC2016,SC2027,SC2034,SC2086,SC2154"
	shellcheck_excludes=""

	require_cmd git
	require_cmd bash
	require_cmd shellcheck
	require_cmd shfmt

	log_info "Collecting tracked shell scripts"
	git ls-files "*.sh" >"${file_list}"
	if [ ! -s "${file_list}" ]; then
		log_crit "No tracked *.sh files found"
		exit 1
	fi

	log_info "Running syntax checks on all scripts"
	while IFS= read -r file; do
		shebang="$(sed -n '1p' "${file}")"
		case "${shebang}" in
		*"bash"*)
			bash -n "${file}"
			;;
		*)
			sh -n "${file}"
			;;
		esac
	done <"${file_list}"

	log_info "Running shellcheck"
	if [ "${SHELLCHECK_EXCLUDES+x}" = "x" ]; then
		shellcheck_excludes="${SHELLCHECK_EXCLUDES}"
	else
		shellcheck_excludes="${default_shellcheck_excludes}"
	fi

	if [ -n "${shellcheck_excludes}" ]; then
		log_info "Using shellcheck baseline excludes: ${shellcheck_excludes}"
		# shellcheck disable=SC2046
		shellcheck -e "${shellcheck_excludes}" $(cat "${file_list}")
	else
		log_info "Running shellcheck in strict mode (no excludes)"
		# shellcheck disable=SC2046
		shellcheck $(cat "${file_list}")
	fi

	log_info "Running shfmt --diff"
	# shellcheck disable=SC2046
	shfmt --diff $(cat "${file_list}")

	log_info "Running AGENTS.md validation checks"
	sh -n build.sh build-testing.sh scripts/*.sh
	bash -n build/root/install.sh run/root/iptable.sh run/nobody/watchdog.sh run/nobody/nzbget.sh
	bash -n data/scripts/*.sh
	./scripts/sync-rotate-defaults-doc.sh check
	wc -c README-containers.md
	git status --short

	log_info "Quality checks passed"
}

main "$@"
