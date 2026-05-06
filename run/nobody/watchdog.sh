#!/bin/bash

WATCHDOG_SLEEP_SECS=30
VPN_UNHEALTHY_MIN_COOLDOWN=300
VPN_SELFTEST_STARTUP_DELAY_MAX=300
vpn_unhealthy_count=0
vpn_unhealthy_last_action=0
vpn_cron_last_run_minute=""
vpn_selftest_has_run="no"
vpn_selftest_last_run_minute=""
vpn_selftest_mode_logged="no"
vpn_selftest_startup_delay_logged="no"
watchdog_start_epoch="$(date +%s)"

is_positive_integer() {
	[[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -gt 0 ]]
}

is_enabled() {
	case "${1:-}" in
		yes|true|1)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

strip_wrapping_quotes() {
	local value="$1"
	local first_char
	local last_char

	if [[ "${#value}" -ge 2 ]]; then
		first_char="${value:0:1}"
		last_char="${value: -1}"
		if [[ "${first_char}" == '"' && "${last_char}" == '"' ]]; then
			value="${value:1:${#value}-2}"
		elif [[ "${first_char}" == "'" && "${last_char}" == "'" ]]; then
			value="${value:1:${#value}-2}"
		fi
	fi

	echo "${value}"
}

run_script_with_timeout() {
	local timeout_secs="$1"
	shift
	local script="$1"
	shift

	if ! is_positive_integer "${timeout_secs}"; then
		echo "[warn] Script timeout value '${timeout_secs}' is invalid, using default '300' seconds"
		timeout_secs=300
	fi

	if command -v timeout >/dev/null 2>&1; then
		timeout --kill-after=10s "${timeout_secs}s" "${script}" "$@"
	else
		echo "[warn] Command 'timeout' is not available, running '${script}' without timeout"
		"${script}" "$@"
	fi
}

run_vpn_selftest_script() {
	local selftest_script="/home/nobody/vpn-selftest.sh"

	if [[ ! -x "${selftest_script}" ]]; then
		echo "[warn] VPN self-test is enabled but script '${selftest_script}' is missing or not executable"
		return
	fi

	echo "[info] VPN self-test is enabled, running '${selftest_script}'"
	if VPN_ENABLED="${VPN_ENABLED:-yes}" VPN_DEVICE_TYPE="${VPN_DEVICE_TYPE:-}" vpn_ip="${vpn_ip:-}" "${selftest_script}"; then
		echo "[info] VPN self-test completed"
	else
		echo "[warn] VPN self-test reported one or more critical checks"
	fi
}

get_vpn_selftest_mode() {
	local configured="${VPN_SELFTEST_ENABLED:-no}"
	configured="$(strip_wrapping_quotes "${configured}")"

	case "${configured}" in
		""|no|false|0)
			echo "no"
			;;
		yes|true|1)
			echo "yes"
			;;
		*)
			echo "${configured}"
			;;
	esac
}

get_vpn_selftest_startup_delay() {
	local configured="${VPN_SELFTEST_STARTUP_DELAY:-20}"

	if ! [[ "${configured}" =~ ^[0-9]+$ ]]; then
		echo "[warn] VPN_SELFTEST_STARTUP_DELAY value '${configured}' is invalid, using default '20' seconds"
		configured=20
	fi
	if [[ "${configured}" -gt "${VPN_SELFTEST_STARTUP_DELAY_MAX}" ]]; then
		echo "[warn] VPN_SELFTEST_STARTUP_DELAY value '${configured}' is above maximum '${VPN_SELFTEST_STARTUP_DELAY_MAX}' seconds, using '${VPN_SELFTEST_STARTUP_DELAY_MAX}' seconds"
		configured="${VPN_SELFTEST_STARTUP_DELAY_MAX}"
	fi

	echo "${configured}"
}

handle_vpn_selftest() {
	local mode
	local current_run_minute
	local startup_delay
	local now
	local elapsed

	mode="$(get_vpn_selftest_mode)"
	if [[ "${vpn_selftest_mode_logged}" == "no" ]]; then
		echo "[info] VPN self-test watchdog mode '${mode}' (VPN_SELFTEST_ENABLED='${VPN_SELFTEST_ENABLED:-no}')"
		vpn_selftest_mode_logged="yes"
	fi
	if [[ "${mode}" == "no" ]]; then
		return
	fi

	if [[ "${mode}" == "yes" ]]; then
		if [[ "${vpn_selftest_has_run}" == "yes" ]]; then
			return
		fi
		startup_delay="$(get_vpn_selftest_startup_delay)"
		now="$(date +%s)"
		elapsed=$((now-watchdog_start_epoch))
		if [[ "${elapsed}" -lt "${startup_delay}" ]]; then
			if [[ "${vpn_selftest_startup_delay_logged}" == "no" ]]; then
				echo "[info] Delaying one-shot VPN self-test by ${startup_delay} seconds after watchdog start (elapsed ${elapsed}s)"
				vpn_selftest_startup_delay_logged="yes"
			fi
			return
		fi
		run_vpn_selftest_script
		vpn_selftest_has_run="yes"
		return
	fi

	current_run_minute="$(date +%Y%m%d%H%M)"
	if [[ "${vpn_selftest_last_run_minute}" == "${current_run_minute}" ]]; then
		return
	fi

	if cron_schedule_matches_now "${mode}" "VPN_SELFTEST_ENABLED"; then
		run_vpn_selftest_script
		vpn_selftest_last_run_minute="${current_run_minute}"
	fi
}

get_vpn_unhealthy_after() {
	local configured="${VPN_UNHEALTHY_AFTER:-10}"

	if ! is_positive_integer "${configured}"; then
		echo "[warn] VPN_UNHEALTHY_AFTER value '${configured}' is invalid, using default '10'"
		configured=10
	fi

	echo "${configured}"
}

get_vpn_unhealthy_cooldown() {
	local configured="${VPN_UNHEALTHY_COOLDOWN:-${VPN_UNHEALTHY_MIN_COOLDOWN}}"

	if ! is_positive_integer "${configured}"; then
		echo "[warn] VPN_UNHEALTHY_COOLDOWN value '${configured}' is invalid, using minimum '${VPN_UNHEALTHY_MIN_COOLDOWN}' seconds"
		configured="${VPN_UNHEALTHY_MIN_COOLDOWN}"
	fi

	if [[ "${configured}" -lt "${VPN_UNHEALTHY_MIN_COOLDOWN}" ]]; then
		echo "[warn] VPN_UNHEALTHY_COOLDOWN value '${configured}' is below minimum '${VPN_UNHEALTHY_MIN_COOLDOWN}' seconds, using '${VPN_UNHEALTHY_MIN_COOLDOWN}' seconds"
		configured="${VPN_UNHEALTHY_MIN_COOLDOWN}"
	fi

	echo "${configured}"
}

handle_vpn_unhealthy() {
	local action="${VPN_UNHEALTHY_ACTION:-none}"
	local after
	local cooldown
	local exit_delay
	local now
	local elapsed

	if [[ "${action}" == "none" || -z "${action}" ]]; then
		return
	fi

	after=$(get_vpn_unhealthy_after)
	cooldown=$(get_vpn_unhealthy_cooldown)

	if [[ "${vpn_unhealthy_count}" -lt "${after}" ]]; then
		return
	fi

	now=$(date +%s)
	elapsed=$((now-vpn_unhealthy_last_action))

	if [[ "${vpn_unhealthy_last_action}" -ne 0 && "${elapsed}" -lt "${cooldown}" ]]; then
		if is_enabled "${DEBUG:-}"; then
			echo "[debug] VPN unhealthy action '${action}' suppressed by cooldown (${elapsed}/${cooldown} seconds)"
		fi
		return
	fi

	case "${action}" in
		script|script+exit)
			if [[ -z "${VPN_UNHEALTHY_SCRIPT:-}" ]]; then
				echo "[warn] VPN_UNHEALTHY_ACTION is 'script' but VPN_UNHEALTHY_SCRIPT is not set"
				return
			fi
			if [[ ! -x "${VPN_UNHEALTHY_SCRIPT}" ]]; then
				echo "[warn] VPN_UNHEALTHY_SCRIPT '${VPN_UNHEALTHY_SCRIPT}' is not executable"
				return
			fi
			echo "[warn] VPN has been unhealthy for ${vpn_unhealthy_count} watchdog checks, running '${VPN_UNHEALTHY_SCRIPT}'"
			if ! VPN_UNHEALTHY_COUNT="${vpn_unhealthy_count}" run_script_with_timeout "${VPN_UNHEALTHY_SCRIPT_TIMEOUT:-300}" "${VPN_UNHEALTHY_SCRIPT}"; then
				echo "[warn] VPN_UNHEALTHY_SCRIPT '${VPN_UNHEALTHY_SCRIPT}' failed or timed out"
				vpn_unhealthy_last_action="${now}"
				return
			fi
			vpn_unhealthy_last_action="${now}"
			if [[ "${action}" == "script+exit" ]]; then
				exit_delay="${VPN_UNHEALTHY_EXIT_DELAY:-5}"
				if ! is_positive_integer "${exit_delay}"; then
					echo "[warn] VPN_UNHEALTHY_EXIT_DELAY value '${exit_delay}' is invalid, using default '5' seconds"
					exit_delay=5
				fi
				echo "[crit] VPN unhealthy script completed, exiting watchdog in ${exit_delay} seconds by request"
				sleep "${exit_delay}s"
				exit 1
			fi
			;;
		exit)
			echo "[crit] VPN has been unhealthy for ${vpn_unhealthy_count} watchdog checks, exiting watchdog by request"
			exit 1
			;;
		*)
			echo "[warn] VPN_UNHEALTHY_ACTION '${action}' is not supported, use 'none', 'script', 'script+exit', or 'exit'"
			;;
	esac
}

vpn_unhealthy_test_enabled() {
	is_enabled "${VPN_UNHEALTHY_TEST:-no}"
}

cron_number_matches() {
	local value="$1"
	local field="$2"
	local min="$3"
	local max="$4"
	local part
	local base
	local step
	local start
	local end

	IFS=',' read -ra parts <<< "${field}"
	for part in "${parts[@]}"; do
		if [[ -z "${part}" ]]; then
			return 1
		fi

		base="${part}"
		step=1
		if [[ "${part}" == */* ]]; then
			base="${part%%/*}"
			step="${part##*/}"
			if ! is_positive_integer "${step}"; then
				return 1
			fi
		fi

		if [[ "${base}" == "*" ]]; then
			start="${min}"
			end="${max}"
		elif [[ "${base}" == *-* ]]; then
			start="${base%-*}"
			end="${base#*-}"
		else
			start="${base}"
			end="${base}"
		fi

		if ! [[ "${start}" =~ ^[0-9]+$ && "${end}" =~ ^[0-9]+$ ]]; then
			return 1
		fi
		if [[ "${start}" -lt "${min}" || "${end}" -gt "${max}" || "${start}" -gt "${end}" ]]; then
			return 1
		fi

		if [[ "${value}" -ge "${start}" && "${value}" -le "${end}" && $(((value-start)%step)) -eq 0 ]]; then
			return 0
		fi
	done

	return 1
}

cron_schedule_matches_now() {
	local schedule="${1}"
	local schedule_name="${2:-VPN_CRON_SCHEDULE}"
	local minute
	local hour
	local day
	local month
	local weekday
	local current_minute
	local current_hour
	local current_day
	local current_month
	local current_weekday

	read -r minute hour day month weekday extra <<< "${schedule}"
	if [[ -z "${minute}" || -z "${hour}" || -z "${day}" || -z "${month}" || -z "${weekday}" || -n "${extra:-}" ]]; then
		echo "[warn] ${schedule_name} '${schedule}' is invalid, expected 5 fields like '* * * * *'"
		return 1
	fi

	current_minute=$(date +%M)
	current_hour=$(date +%H)
	current_day=$(date +%d)
	current_month=$(date +%m)
	current_weekday=$(date +%w)

	current_minute=$((10#${current_minute}))
	current_hour=$((10#${current_hour}))
	current_day=$((10#${current_day}))
	current_month=$((10#${current_month}))
	current_weekday=$((10#${current_weekday}))

	cron_number_matches "${current_minute}" "${minute}" 0 59 || return 1
	cron_number_matches "${current_hour}" "${hour}" 0 23 || return 1
	cron_number_matches "${current_day}" "${day}" 1 31 || return 1
	cron_number_matches "${current_month}" "${month}" 1 12 || return 1
	if ! cron_number_matches "${current_weekday}" "${weekday}" 0 7; then
		if [[ "${current_weekday}" -eq 0 ]]; then
			cron_number_matches 7 "${weekday}" 0 7 || return 1
		else
			return 1
		fi
	fi

	return 0
}

handle_vpn_cron_script() {
	local schedule="${VPN_CRON_SCHEDULE:-}"
	local script="${VPN_CRON_SCRIPT:-}"
	local current_run_minute

	schedule="$(strip_wrapping_quotes "${schedule}")"
	script="$(strip_wrapping_quotes "${script}")"

	if [[ -z "${schedule}" && -z "${script}" ]]; then
		return
	fi

	if [[ -z "${schedule}" || -z "${script}" ]]; then
		echo "[warn] VPN_CRON_SCHEDULE and VPN_CRON_SCRIPT must both be set to enable scheduled script execution"
		return
	fi

	if [[ ! -x "${script}" ]]; then
		echo "[warn] VPN_CRON_SCRIPT '${script}' is not executable"
		return
	fi

	current_run_minute="$(date +%Y%m%d%H%M)"
	if [[ "${vpn_cron_last_run_minute}" == "${current_run_minute}" ]]; then
		return
	fi

	if cron_schedule_matches_now "${schedule}" "VPN_CRON_SCHEDULE"; then
		echo "[info] VPN_CRON_SCHEDULE '${schedule}' matched, running '${script}'"
		if VPN_CRON_SCHEDULE="${schedule}" run_script_with_timeout "${VPN_CRON_SCRIPT_TIMEOUT:-300}" "${script}"; then
			echo "[info] VPN_CRON_SCRIPT '${script}' completed"
		else
			echo "[warn] VPN_CRON_SCRIPT '${script}' failed or timed out"
		fi
		vpn_cron_last_run_minute="${current_run_minute}"
	fi
}

# while loop to check ip and port
while true; do

	handle_vpn_cron_script

	# reset triggers to negative values
	nzbget_running="false"
	privoxy_running="false"
	ip_change="false"

	if is_enabled "${VPN_ENABLED:-yes}"; then

		# run script to get all required info
		source /home/nobody/preruncheck.sh

		if vpn_unhealthy_test_enabled; then
			echo "[warn] VPN_UNHEALTHY_TEST is enabled, simulating missing VPN IP for action testing"
			vpn_ip=""
		fi

		# if vpn_ip is not blank then run, otherwise log warning
		if [[ ! -z "${vpn_ip}" ]]; then
			if [[ "${vpn_unhealthy_count}" -gt 0 ]]; then
				echo "[info] VPN IP detected, resetting unhealthy counter"
			fi
			vpn_unhealthy_count=0

			# check if nzbget is running, if not then skip shutdown of process
			if ! pgrep -x nzbget > /dev/null; then

				echo "[info] nzbget not running"

			else

				# mark as nzbget as running
				nzbget_running="true"

			fi

			if is_enabled "${ENABLE_PRIVOXY:-}"; then

				# check if privoxy is running, if not then skip shutdown of process
				if ! pgrep -fa "/usr/bin/privoxy" > /dev/null; then

					echo "[info] Privoxy not running"

				else

					# mark as privoxy as running
					privoxy_running="true"

				fi

			fi

			if [[ "${nzbget_running}" == "false" ]]; then

				# run script to start nzbget
				source /home/nobody/nzbget.sh

			fi

			if is_enabled "${ENABLE_PRIVOXY:-}"; then

				if [[ "${privoxy_running}" == "false" ]]; then

					# run script to start privoxy
					source /home/nobody/privoxy.sh

				fi

			fi


		else

			echo "[warn] VPN IP not detected, VPN tunnel maybe down"
			vpn_unhealthy_count=$((vpn_unhealthy_count+1))
			handle_vpn_unhealthy

		fi

	else

		# check if nzbget is running, if not then start via nzbget.sh
		if ! pgrep -x nzbget > /dev/null; then

			echo "[info] Nzbget not running"

			# run script to start nzbget
			source /home/nobody/nzbget.sh

		fi

		if is_enabled "${ENABLE_PRIVOXY:-}"; then

			# check if privoxy is running, if not then start via privoxy.sh
			if ! pgrep -fa "/usr/bin/privoxy" > /dev/null; then

				echo "[info] Privoxy not running"

				# run script to start privoxy
				source /home/nobody/privoxy.sh

			fi

		fi

	fi

	if is_enabled "${DEBUG:-}" && is_enabled "${VPN_ENABLED:-yes}"; then
		echo "[debug] VPN IP is ${vpn_ip}"
	fi

	handle_vpn_selftest

	sleep "${WATCHDOG_SLEEP_SECS}s"

done
