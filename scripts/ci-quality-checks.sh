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

is_truthy() {
	value="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
	case "${value}" in
	yes | true | 1)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

run_conflict_marker_check() {
	log_info "Checking repository for unresolved merge conflict markers"
	if git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- . >/dev/null 2>&1; then
		log_crit "Found unresolved merge conflict markers in tracked files"
		git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- .
		exit 1
	fi
}

run_readme_size_guard() {
	readme_path="README-containers.md"
	max_bytes="25000"
	readme_bytes="$(wc -c <"${readme_path}" | tr -d '[:space:]')"
	log_info "Validating ${readme_path} size: ${readme_bytes}/${max_bytes} bytes"
	if [ "${readme_bytes}" -gt "${max_bytes}" ]; then
		log_crit "${readme_path} exceeds Docker Hub limit (${readme_bytes} > ${max_bytes} bytes)"
		exit 1
	fi
}

run_conventional_commit_lint() {
	default_pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._/-]+\))?(!)?: .+'
	commit_pattern="${CI_CONVENTIONAL_COMMIT_PATTERN:-${default_pattern}}"
	commit_range="${CI_CONVENTIONAL_COMMIT_RANGE:-HEAD~20..HEAD}"
	failed="0"

	log_info "Running optional conventional commit lint on range: ${commit_range}"
	if ! git rev-parse "${commit_range}" >/dev/null 2>&1; then
		log_crit "Invalid CI_CONVENTIONAL_COMMIT_RANGE: ${commit_range}"
		exit 1
	fi

	while IFS= read -r subject; do
		if [ -z "${subject}" ]; then
			continue
		fi
		if ! printf '%s\n' "${subject}" | grep -Eq "${commit_pattern}"; then
			log_crit "Non-conventional commit subject: ${subject}"
			failed="1"
		fi
	done <<EOF
$(git log --format=%s "${commit_range}")
EOF

	if [ "${failed}" != "0" ]; then
		log_crit "Conventional commit lint failed; adjust subjects or pattern/range overrides"
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

	run_conflict_marker_check
	run_readme_size_guard

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
	bash -n data/scripts/*.sh data/scripts/*/*.sh
	./scripts/sync-rotate-defaults-doc.sh check
	wc -c README-containers.md
	git status --short

	if is_truthy "${CI_CONVENTIONAL_COMMIT_LINT:-}"; then
		run_conventional_commit_lint
	else
		log_info "Skipping conventional commit lint (set CI_CONVENTIONAL_COMMIT_LINT=true to enable)"
	fi

	log_info "Quality checks passed"
}

main "$@"
