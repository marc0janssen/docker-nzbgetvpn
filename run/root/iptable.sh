#!/bin/bash

shared_lib="/usr/local/share/nzbgetvpn/scripts/lib.sh"
if [[ ! -r "${shared_lib}" ]]; then
	echo "[crit] Shared helper library not found at '/usr/local/share/nzbgetvpn/scripts/lib.sh'"
	exit 1
fi
# shellcheck source=/dev/null
. "${shared_lib}"

is_valid_port() {
	[[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -ge 1 && "$1" -le 65535 ]]
}

is_valid_interface_name() {
	[[ "$1" =~ ^[[:alnum:]_.:-]+$ ]]
}

iptables_append_if_missing() {
	local table="$1"
	shift
	if ! iptables -t "${table}" -C "$@" >/dev/null 2>&1; then
		iptables -t "${table}" -A "$@"
	fi
}

validate_cidr_list() {
	local name="$1"
	shift
	local item

	for item in "$@"; do
		item=$(trim "${item}")
		if [[ -z "${item}" ]]; then
			echo "[crit] ${name} contains an empty network, exiting..."
			exit 1
		fi
		if ! [[ "${item}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$ ]] || ! ipcalc "${item}" >/dev/null 2>&1; then
			echo "[crit] ${name} contains invalid CIDR '${item}', exiting..."
			exit 1
		fi
	done
}

validate_port_list() {
	local name="$1"
	shift
	local item

	for item in "$@"; do
		item=$(trim "${item}")
		if ! is_valid_port "${item}"; then
			echo "[crit] ${name} contains invalid port '${item}', exiting..."
			exit 1
		fi
	done
}

harden_wireguard_config_permissions() {
	local conf_file
	local wireguard_config_dir="/config/wireguard"

	if [[ "${VPN_CLIENT:-}" != "wireguard" || ! -d "${wireguard_config_dir}" ]]; then
		return
	fi

	shopt -s nullglob
	for conf_file in "${wireguard_config_dir}"/*.conf; do
		if is_enabled "${DEBUG:-}"; then
			echo "[debug] Setting secure permissions on '${conf_file}'"
		fi
		if ! chmod 600 "${conf_file}"; then
			echo "[warn] Unable to set secure permissions on '${conf_file}'"
		fi
	done
	shopt -u nullglob
}

harden_wireguard_config_permissions

# identify docker bridge interface name by looking at defult route
docker_interface=$(ip -4 route ls | grep default | xargs | grep -o -P '[^\s]+$')
if [[ -z "${docker_interface}" ]] || ! is_valid_interface_name "${docker_interface}"; then
	echo "[crit] Unable to identify a valid docker interface, exiting..."
	exit 1
fi
if is_enabled "${DEBUG:-}"; then
	echo "[debug] Docker interface defined as ${docker_interface}"
fi

# identify ip for local gateway (eth0)
default_gateway=$(ip route show default | awk '/default/ {print $3}')
if [[ -z "${default_gateway}" ]]; then
	echo "[crit] Unable to identify default gateway, exiting..."
	exit 1
fi
echo "[info] Default route for container is ${default_gateway}"

# identify ip for docker bridge interface
docker_ip=$(ifconfig "${docker_interface}" | grep -P -o -m 1 '(?<=inet\s)[^\s]+')
if [[ -z "${docker_ip}" ]]; then
	echo "[crit] Unable to identify docker IP for ${docker_interface}, exiting..."
	exit 1
fi
if is_enabled "${DEBUG:-}"; then
	echo "[debug] Docker IP defined as ${docker_ip}"
fi

# identify netmask for docker bridge interface
docker_mask=$(ifconfig "${docker_interface}" | grep -P -o -m 1 '(?<=netmask\s)[^\s]+')
if [[ -z "${docker_mask}" ]]; then
	echo "[crit] Unable to identify docker netmask for ${docker_interface}, exiting..."
	exit 1
fi
if is_enabled "${DEBUG:-}"; then
	echo "[debug] Docker netmask defined as ${docker_mask}"
fi

# convert netmask into cidr format
docker_network_cidr=$(trim "$(ipcalc "${docker_ip}" "${docker_mask}" | grep -P -o -m 1 "(?<=Network:)\s+[^\s]+")")
if [[ -z "${docker_network_cidr}" ]]; then
	echo "[crit] Unable to calculate docker network CIDR, exiting..."
	exit 1
fi
echo "[info] Docker network defined as ${docker_network_cidr}"

# split comma separated string into list from LAN_NETWORK env variable
IFS=',' read -ra lan_network_list <<<"${LAN_NETWORK:-}"
if [[ -z "${LAN_NETWORK:-}" ]]; then
	echo "[crit] LAN_NETWORK is not set, exiting..."
	exit 1
fi
validate_cidr_list "LAN_NETWORK" "${lan_network_list[@]}"

# split comma separated string into array from VPN_REMOTE_PORT env var
IFS=',' read -ra vpn_remote_port_list <<<"${VPN_REMOTE_PORT:-}"
if [[ -z "${VPN_REMOTE_PORT:-}" ]]; then
	echo "[crit] VPN_REMOTE_PORT is not set, exiting..."
	exit 1
fi
validate_port_list "VPN_REMOTE_PORT" "${vpn_remote_port_list[@]}"

# split comma separated string into array for tcp and udp protocols (both required)
IFS=',' read -ra vpn_remote_endpoint_protocol_list <<<"tcp,udp"

# split comma separated string into list from ADDITIONAL_PORTS env variable
IFS=',' read -ra additional_port_list <<<"${ADDITIONAL_PORTS:-}"
if [[ ! -z "${ADDITIONAL_PORTS:-}" ]]; then
	validate_port_list "ADDITIONAL_PORTS" "${additional_port_list[@]}"
fi

if [[ -z "${VPN_DEVICE_TYPE:-}" ]] || ! is_valid_interface_name "${VPN_DEVICE_TYPE}"; then
	echo "[crit] VPN_DEVICE_TYPE is not set to a valid interface name, exiting..."
	exit 1
fi

# split comma separated string into array for tcp and udp protocols (both required)
IFS=',' read -ra additional_port_protocol_list <<<"tcp,udp"

# ip route
###

# process lan networks in the list
for lan_network_item in "${lan_network_list[@]}"; do

	# strip whitespace from start and end of lan_network_item
	lan_network_item=$(echo "${lan_network_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

	echo "[info] Ensuring route for ${lan_network_item} via docker ${docker_interface}"
	ip route replace "${lan_network_item}" via "${default_gateway}" dev "${docker_interface}"

done

echo "[info] ip route defined as follows..."
ip route | sed '/^[[:space:]]*$/d'

# setup iptables marks to allow routing of defined ports via lan
###

if is_enabled "${DEBUG:-}"; then
	echo "[debug] Modules currently loaded for kernel"
	lsmod
fi

# Detect mangle table support by probing iptables directly. Some kernels
# provide this support built-in and won't expose an iptable_mangle module.
iptable_mangle_supported=0
webui_http_table_id=6789
if iptables -t mangle -S >/dev/null 2>&1; then
	iptable_mangle_supported=1
	echo "[info] iptables mangle support detected, adding fwmark for tables"

	# setup route for nzbget webui http using set-mark to route traffic for
	# port 6789 to lan interface. Always use numeric table id for compatibility.
	if [[ -f /etc/iproute2/rt_tables ]]; then
		if ! grep -Eq "^[[:space:]]*${webui_http_table_id}[[:space:]]+webui_http([[:space:]]|$)" /etc/iproute2/rt_tables; then
			echo "${webui_http_table_id}    webui_http" >>/etc/iproute2/rt_tables
		fi
	else
		echo "[warn] /etc/iproute2/rt_tables not found; using numeric routing table ${webui_http_table_id}"
	fi

	if ! ip rule show | awk -v table_id="${webui_http_table_id}" '$0 ~ /fwmark 0x1/ && $0 ~ ("lookup " table_id "($| )") { found=1 } END { exit(found ? 0 : 1) }'; then
		ip rule add fwmark 1 table "${webui_http_table_id}"
	fi
	ip route replace default via "${default_gateway}" table "${webui_http_table_id}"
else
	echo "[warn] iptables mangle support unavailable, Web UI/Privoxy outside LAN may not work"
fi

# input iptable rules
###

# set policy to drop ipv4 for input
iptables -P INPUT DROP

# set policy to drop ipv6 for input
ip6tables -P INPUT DROP 1>&- 2>&-

# accept input to/from docker containers (172.x range is internal dhcp)
iptables_append_if_missing filter INPUT -s "${docker_network_cidr}" -d "${docker_network_cidr}" -j ACCEPT

# iterate over array and add all remote vpn ports and protocols
for vpn_remote_port_item in "${vpn_remote_port_list[@]}"; do

	for vpn_remote_protocol_item in "${vpn_remote_endpoint_protocol_list[@]}"; do

		# accept input to vpn gateway
		iptables_append_if_missing filter INPUT -i "${docker_interface}" -p "${vpn_remote_protocol_item}" --sport "${vpn_remote_port_item}" -j ACCEPT

	done

done

# accept input to nzbget webui port 6789
iptables_append_if_missing filter INPUT -i "${docker_interface}" -p tcp --dport 6789 -j ACCEPT
iptables_append_if_missing filter INPUT -i "${docker_interface}" -p tcp --sport 6789 -j ACCEPT

# additional port list for scripts or container linking
if [[ ! -z "${ADDITIONAL_PORTS}" ]]; then

	# process additional ports in the list
	for additional_port_item in "${additional_port_list[@]}"; do

		# strip whitespace from start and end of additional_port_item
		additional_port_item=$(echo "${additional_port_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

		echo "[info] Adding additional incoming port ${additional_port_item} for ${docker_interface}"

		for additional_port_protocol_item in "${additional_port_protocol_list[@]}"; do

			# accept input to additional port for "${docker_interface}"
			iptables_append_if_missing filter INPUT -i "${docker_interface}" -p "${additional_port_protocol_item}" --dport "${additional_port_item}" -j ACCEPT
			iptables_append_if_missing filter INPUT -i "${docker_interface}" -p "${additional_port_protocol_item}" --sport "${additional_port_item}" -j ACCEPT

		done

	done

fi

# process lan networks in the list
for lan_network_item in "${lan_network_list[@]}"; do

	# strip whitespace from start and end of lan_network_item
	lan_network_item=$(echo "${lan_network_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

	# accept input to privoxy if enabled
	if is_enabled "${ENABLE_PRIVOXY:-}"; then
		iptables_append_if_missing filter INPUT -i "${docker_interface}" -p tcp -s "${lan_network_item}" -d "${docker_network_cidr}" -j ACCEPT
	fi

done

# accept input icmp (ping)
iptables_append_if_missing filter INPUT -p icmp --icmp-type echo-reply -j ACCEPT

# accept input to local loopback
iptables_append_if_missing filter INPUT -i lo -j ACCEPT

# accept input to tunnel adapter
iptables_append_if_missing filter INPUT -i "${VPN_DEVICE_TYPE}" -j ACCEPT

# forward iptable rules
###

# set policy to drop ipv4 for forward
iptables -P FORWARD DROP

# set policy to drop ipv6 for forward
ip6tables -P FORWARD DROP 1>&- 2>&-

# output iptable rules
###

# set policy to drop ipv4 for output
iptables -P OUTPUT DROP

# set policy to drop ipv6 for output
ip6tables -P OUTPUT DROP 1>&- 2>&-

# accept output to/from docker containers (172.x range is internal dhcp)
iptables_append_if_missing filter OUTPUT -s "${docker_network_cidr}" -d "${docker_network_cidr}" -j ACCEPT

# iterate over array and add all remote vpn ports and protocols
for vpn_remote_port_item in "${vpn_remote_port_list[@]}"; do

	for vpn_remote_protocol_item in "${vpn_remote_endpoint_protocol_list[@]}"; do

		# accept output to vpn gateway
		iptables_append_if_missing filter OUTPUT -o "${docker_interface}" -p "${vpn_remote_protocol_item}" --dport "${vpn_remote_port_item}" -j ACCEPT

	done

done

# if iptables mangle support is available then use mark
if [[ "${iptable_mangle_supported}" == 1 ]]; then

	# accept output from nzbget webui port 6789 - used for external access
	iptables_append_if_missing mangle OUTPUT -p tcp --dport 6789 -j MARK --set-mark 1
	iptables_append_if_missing mangle OUTPUT -p tcp --sport 6789 -j MARK --set-mark 1

fi

# accept output from nzbget webui port 6789 - used for lan access
iptables_append_if_missing filter OUTPUT -o "${docker_interface}" -p tcp --dport 6789 -j ACCEPT
iptables_append_if_missing filter OUTPUT -o "${docker_interface}" -p tcp --sport 6789 -j ACCEPT

# additional port list for scripts or container linking
if [[ ! -z "${ADDITIONAL_PORTS}" ]]; then

	# process additional ports in the list
	for additional_port_item in "${additional_port_list[@]}"; do

		# strip whitespace from start and end of additional_port_item
		additional_port_item=$(echo "${additional_port_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

		echo "[info] Adding additional outgoing port ${additional_port_item} for ${docker_interface}"

		for additional_port_protocol_item in "${additional_port_protocol_list[@]}"; do

			# accept output to additional port for lan interface
			iptables_append_if_missing filter OUTPUT -o "${docker_interface}" -p "${additional_port_protocol_item}" --dport "${additional_port_item}" -j ACCEPT
			iptables_append_if_missing filter OUTPUT -o "${docker_interface}" -p "${additional_port_protocol_item}" --sport "${additional_port_item}" -j ACCEPT

		done

	done

fi

# process lan networks in the list
for lan_network_item in "${lan_network_list[@]}"; do

	# strip whitespace from start and end of lan_network_item
	lan_network_item=$(echo "${lan_network_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

	# accept output from privoxy if enabled - used for lan access
	if is_enabled "${ENABLE_PRIVOXY:-}"; then
		iptables_append_if_missing filter OUTPUT -o "${docker_interface}" -p tcp -s "${docker_network_cidr}" -d "${lan_network_item}" -j ACCEPT
	fi

done

# accept output for icmp (ping)
iptables_append_if_missing filter OUTPUT -p icmp --icmp-type echo-request -j ACCEPT

# accept output from local loopback adapter
iptables_append_if_missing filter OUTPUT -o lo -j ACCEPT

# accept output from tunnel adapter
iptables_append_if_missing filter OUTPUT -o "${VPN_DEVICE_TYPE}" -j ACCEPT

echo "[info] iptables defined as follows..."
iptables -S 2>&1 | sed '/^[[:space:]]*$/d' | tee /tmp/getiptables
chmod +r /tmp/getiptables
