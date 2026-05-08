#!/bin/sh
set -eu

usage() {
	cat <<'EOF'
Usage:
  run-container-helper.sh [--container <name>] <script-name> [script-args...]

Examples:
  run-container-helper.sh doctor.sh
  run-container-helper.sh --container nzbgetvpn rotate_on_poor_speed.sh
  run-container-helper.sh container/doctor.sh --help

Notes:
  - Scripts run inside the container via /data/scripts/<script-name>.
  - "<script-name>" may be provided as a basename (doctor.sh) or with a prefix (container/doctor.sh).
EOF
}

log_info() {
	printf '[info] %s\n' "$*"
}

log_crit() {
	printf '[crit] %s\n' "$*" >&2
	exit 1
}

container_name="nzbgetvpn"

while [ "$#" -gt 0 ]; do
	case "$1" in
	--container)
		[ "$#" -ge 2 ] || log_crit "--container requires a value"
		container_name="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	--)
		shift
		break
		;;
	-*)
		log_crit "Unknown option: $1"
		;;
	*)
		break
		;;
	esac
done

[ "$#" -ge 1 ] || {
	usage
	exit 1
}

raw_script_name="$1"
shift

script_name="$(basename -- "${raw_script_name}")"

case "${script_name}" in
*.sh)
	;;
*)
	log_crit "Script name must end with .sh (got '${raw_script_name}')"
	;;
esac

case "${script_name}" in
*/* | "" | "." | "..")
	log_crit "Invalid script name '${raw_script_name}'"
	;;
lib.sh)
	log_crit "'lib.sh' is a shared library and not directly executable"
	;;
esac

command -v docker >/dev/null 2>&1 || log_crit "docker command not found on host"

running_state="$(docker inspect -f '{{.State.Running}}' "${container_name}" 2>/dev/null || true)"
[ "${running_state}" = "true" ] || log_crit "Container '${container_name}' is not running"

target_script="/data/scripts/${script_name}"
docker exec "${container_name}" test -x "${target_script}" ||
	log_crit "Script '${target_script}' not found/executable in container '${container_name}'"

log_info "Running '${target_script}' inside container '${container_name}'"
exec docker exec "${container_name}" "${target_script}" "$@"
