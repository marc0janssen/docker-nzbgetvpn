#!/usr/bin/env bash

set -euo pipefail

log() {
    local level="$1"
    shift
    printf '[%s] %s\n' "$level" "$*"
}

get_default_interface() {
    ip -4 route show default | awk 'NR==1 {print $5}'
}

get_default_gateway() {
    ip route show default | awk 'NR==1 {print $3}'
}

get_interface_cidr() {
    local interface="$1"
    local address
    address=$(ip -4 addr show dev "$interface" | awk '/inet / {print $2; exit}')
    printf '%s' "$address"
}

read_csv_into_array() {
    local variable_name="$1"
    local csv_value="${2:-}"
    IFS=',' read -r -a "$variable_name" <<< "$csv_value"
}

docker_interface=$(get_default_interface)
if [[ -z ${docker_interface} ]]; then
    log crit 'Unable to determine docker interface from default route'
    exit 1
fi
if [[ ${DEBUG:-false} == true ]]; then
    log debug "Docker interface defined as ${docker_interface}"
fi

default_gateway=$(get_default_gateway)
log info "Default route for container is ${default_gateway}"

docker_cidr=$(get_interface_cidr "${docker_interface}")
if [[ -z ${docker_cidr} ]]; then
    log crit "Unable to determine CIDR for ${docker_interface}"
    exit 1
fi
if [[ ${DEBUG:-false} == true ]]; then
    log debug "Docker CIDR defined as ${docker_cidr}"
fi

ipcalc_output=$(ipcalc "${docker_cidr}")
docker_network_cidr=$(awk '/^Network:/ {print $2}' <<< "${ipcalc_output}")
log info "Docker network defined as ${docker_network_cidr}"

read_csv_into_array lan_network_list "${LAN_NETWORK:-}"
read_csv_into_array vpn_remote_port_list "${VPN_REMOTE_PORT:-}"
additional_ports_csv="${ADDITIONAL_PORTS:-}"
read_csv_into_array additional_port_list "${additional_ports_csv}"

for lan_network_item in "${lan_network_list[@]}"; do
    lan_network_item=$(sed -e 's~^[ \t]*~~;s~[ \t]*$~~' <<< "${lan_network_item}")
    [[ -z ${lan_network_item} ]] && continue
    log info "Adding ${lan_network_item} as route via docker ${docker_interface}"
    ip route replace "${lan_network_item}" via "${default_gateway}" dev "${docker_interface}"
done

log info 'ip route defined as follows...'
log info '--------------------'
ip route
log info '--------------------'

if [[ ${DEBUG:-false} == true ]]; then
    log debug 'Modules currently loaded for kernel'
    lsmod
fi

has_iptable_mangle=false
if lsmod | grep -q iptable_mangle; then
    has_iptable_mangle=true
    log info 'iptable_mangle support detected, adding fwmark for tables'
    if ! grep -q '^6789' /etc/iproute2/rt_tables; then
        printf '6789    webui_http\n' >> /etc/iproute2/rt_tables
    fi
    ip rule add fwmark 1 table webui_http 2>/dev/null || true
    ip route replace default via "${default_gateway}" table webui_http
fi

iptables -P INPUT DROP
ip6tables -P INPUT DROP 1>&- 2>&-
iptables -A INPUT -s "${docker_network_cidr}" -d "${docker_network_cidr}" -j ACCEPT

for vpn_remote_port_item in "${vpn_remote_port_list[@]}"; do
    vpn_remote_port_item=$(sed -e 's~^[ \t]*~~;s~[ \t]*$~~' <<< "${vpn_remote_port_item}")
    [[ -z ${vpn_remote_port_item} ]] && continue
    for protocol in tcp udp; do
        if ! iptables -C INPUT -i "${docker_interface}" -p "${protocol}" --sport "${vpn_remote_port_item}" -j ACCEPT 2>/dev/null; then
            iptables -A INPUT -i "${docker_interface}" -p "${protocol}" --sport "${vpn_remote_port_item}" -j ACCEPT
        fi
    done
done

iptables -A INPUT -i "${docker_interface}" -p tcp --dport 6789 -j ACCEPT
iptables -A INPUT -i "${docker_interface}" -p tcp --sport 6789 -j ACCEPT

for additional_port_item in "${additional_port_list[@]}"; do
    additional_port_item=$(sed -e 's~^[ \t]*~~;s~[ \t]*$~~' <<< "${additional_port_item}")
    [[ -z ${additional_port_item} ]] && continue
    log info "Adding additional incoming port ${additional_port_item} for ${docker_interface}"
    for protocol in tcp udp; do
        iptables -A INPUT -i "${docker_interface}" -p "${protocol}" --dport "${additional_port_item}" -j ACCEPT
        iptables -A INPUT -i "${docker_interface}" -p "${protocol}" --sport "${additional_port_item}" -j ACCEPT
    done
done

for lan_network_item in "${lan_network_list[@]}"; do
    lan_network_item=$(sed -e 's~^[ \t]*~~;s~[ \t]*$~~' <<< "${lan_network_item}")
    [[ -z ${lan_network_item} ]] && continue
    if [[ ${ENABLE_PRIVOXY:-no} == yes ]]; then
        iptables -A INPUT -i "${docker_interface}" -p tcp -s "${lan_network_item}" -d "${docker_network_cidr}" -j ACCEPT
    fi
done

iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i "${VPN_DEVICE_TYPE}" -j ACCEPT

iptables -P FORWARD DROP
ip6tables -P FORWARD DROP 1>&- 2>&-

iptables -P OUTPUT DROP
ip6tables -P OUTPUT DROP 1>&- 2>&-
iptables -A OUTPUT -s "${docker_network_cidr}" -d "${docker_network_cidr}" -j ACCEPT

for vpn_remote_port_item in "${vpn_remote_port_list[@]}"; do
    vpn_remote_port_item=$(sed -e 's~^[ \t]*~~;s~[ \t]*$~~' <<< "${vpn_remote_port_item}")
    [[ -z ${vpn_remote_port_item} ]] && continue
    for protocol in tcp udp; do
        if ! iptables -C OUTPUT -o "${docker_interface}" -p "${protocol}" --dport "${vpn_remote_port_item}" -j ACCEPT 2>/dev/null; then
            iptables -A OUTPUT -o "${docker_interface}" -p "${protocol}" --dport "${vpn_remote_port_item}" -j ACCEPT
        fi
    done
done

if [[ ${has_iptable_mangle} == true ]]; then
    iptables -t mangle -A OUTPUT -p tcp --dport 6789 -j MARK --set-mark 1
    iptables -t mangle -A OUTPUT -p tcp --sport 6789 -j MARK --set-mark 1
fi

iptables -A OUTPUT -o "${docker_interface}" -p tcp --dport 6789 -j ACCEPT
iptables -A OUTPUT -o "${docker_interface}" -p tcp --sport 6789 -j ACCEPT

for additional_port_item in "${additional_port_list[@]}"; do
    additional_port_item=$(sed -e 's~^[ \t]*~~;s~[ \t]*$~~' <<< "${additional_port_item}")
    [[ -z ${additional_port_item} ]] && continue
    log info "Adding additional outgoing port ${additional_port_item} for ${docker_interface}"
    for protocol in tcp udp; do
        iptables -A OUTPUT -o "${docker_interface}" -p "${protocol}" --dport "${additional_port_item}" -j ACCEPT
        iptables -A OUTPUT -o "${docker_interface}" -p "${protocol}" --sport "${additional_port_item}" -j ACCEPT
    done
done

for lan_network_item in "${lan_network_list[@]}"; do
    lan_network_item=$(sed -e 's~^[ \t]*~~;s~[ \t]*$~~' <<< "${lan_network_item}")
    [[ -z ${lan_network_item} ]] && continue
    if [[ ${ENABLE_PRIVOXY:-no} == yes ]]; then
        iptables -A OUTPUT -o "${docker_interface}" -p tcp -s "${docker_network_cidr}" -d "${lan_network_item}" -j ACCEPT
    fi
done

iptables -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o "${VPN_DEVICE_TYPE}" -j ACCEPT

log info 'iptables defined as follows...'
log info '--------------------'
iptables -S 2>&1 | tee /tmp/getiptables
chmod +r /tmp/getiptables
log info '--------------------'
