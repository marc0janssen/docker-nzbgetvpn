#!/usr/bin/env bash
set -Eeuo pipefail

log_info() {
	echo "[info] [smoke] $*"
}

log_crit() {
	echo "[crit] [smoke] $*" >&2
}

cleanup() {
	if [[ "${KEEP_SMOKE_STACK:-no}" == "yes" ]]; then
		log_info "Keeping smoke stack up (KEEP_SMOKE_STACK=yes)"
		return 0
	fi

	log_info "Stopping smoke stack"
	docker compose -f ci/docker-compose.smoke.yml down -v --remove-orphans >/dev/null 2>&1 || true
}

wait_for_port() {
	local name="$1"
	local port="$2"
	local attempts="${3:-60}"
	local sleep_secs="${4:-2}"
	local i

	for ((i = 1; i <= attempts; i += 1)); do
		if nc -z 127.0.0.1 "${port}" >/dev/null 2>&1; then
			log_info "${name} is reachable on ${port}/tcp"
			return 0
		fi
		sleep "${sleep_secs}"
	done

	log_crit "${name} did not become reachable on ${port}/tcp in time"
	return 1
}

wait_for_container_running() {
	local service="$1"
	local attempts="${2:-30}"
	local sleep_secs="${3:-2}"
	local cid=""
	local i

	for ((i = 1; i <= attempts; i += 1)); do
		cid="$(docker compose -f ci/docker-compose.smoke.yml ps -q "${service}" 2>/dev/null || true)"
		if [[ -n "${cid}" ]] && [[ "$(docker inspect -f '{{.State.Running}}' "${cid}" 2>/dev/null || true)" == "true" ]]; then
			log_info "Container ${service} is running"
			return 0
		fi
		sleep "${sleep_secs}"
	done

	log_crit "Container ${service} did not reach running state in time"
	return 1
}

run_doctor_heal_recovery_check() {
	local service="$1"
	local before_hash
	local after_hash
	local bundled_hash
	local latest_backup_dir

	log_info "Validating doctor --heal recovery path"
	before_hash="$(docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" bash -lc 'sha256sum /data/scripts/lib.sh | awk "{print \$1}"')"
	bundled_hash="$(docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" bash -lc 'sha256sum /usr/local/share/nzbgetvpn/scripts/lib.sh | awk "{print \$1}"')"
	if [[ -z "${before_hash}" || -z "${bundled_hash}" ]]; then
		log_crit "Unable to read lib.sh hashes before heal test"
		return 1
	fi

	log_info "Injecting drift into /data/scripts/lib.sh"
	docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" bash -lc "printf '\n# smoke-heal-drift\n' >> /data/scripts/lib.sh"
	after_hash="$(docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" bash -lc 'sha256sum /data/scripts/lib.sh | awk "{print \$1}"')"
	if [[ "${before_hash}" == "${after_hash}" ]]; then
		log_crit "Failed to inject drift for doctor --heal test"
		return 1
	fi

	log_info "Running doctor --heal"
	docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" /data/scripts/container/doctor.sh --heal

	log_info "Verifying healed lib.sh matches bundled template"
	after_hash="$(docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" bash -lc 'sha256sum /data/scripts/lib.sh | awk "{print \$1}"')"
	if [[ "${after_hash}" != "${bundled_hash}" ]]; then
		log_crit "doctor --heal did not restore /data/scripts/lib.sh to bundled state"
		return 1
	fi

	log_info "Verifying doctor heal backup was created"
	latest_backup_dir="$(docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" bash -lc 'ls -1dt /data/backups/doctor-heal-* 2>/dev/null | head -n1 || true')"
	if [[ -z "${latest_backup_dir}" ]]; then
		log_crit "doctor --heal did not create backup directory under /data/backups"
		return 1
	fi
	docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" bash -lc "[ -f '${latest_backup_dir}/data/scripts/lib.sh' ]"
	log_info "doctor --heal recovery check passed"
}

main() {
	local service="nzbgetvpn-smoke"
	local smoke_platform="${SMOKE_PLATFORM:-linux/amd64}"

	trap cleanup EXIT

	log_info "Starting smoke stack"
	log_info "Using platform ${smoke_platform}"
	export DOCKER_DEFAULT_PLATFORM="${smoke_platform}"
	docker compose -f ci/docker-compose.smoke.yml up -d --build

	log_info "Waiting for container to be running"
	if ! wait_for_container_running "${service}"; then
		log_crit "Container is not running after startup"
		docker compose -f ci/docker-compose.smoke.yml logs --no-color
		exit 1
	fi

	wait_for_port "NZBGet Web UI" 6789
	wait_for_port "Privoxy" 8118

	log_info "Running healthcheck-backed self-test"
	docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" /root/healthcheck.sh

	log_info "Running direct self-test"
	docker compose -f ci/docker-compose.smoke.yml exec -T "${service}" /home/nobody/vpn-selftest.sh

	run_doctor_heal_recovery_check "${service}"

	log_info "Smoke test passed"
}

main "$@"
