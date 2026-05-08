#!/bin/bash

# exit script if return code != 0
set -e

# note do NOT download build scripts - inherited from int script with envvars common defined

# detect image arch
####

OS_ARCH=$(cat /etc/os-release | grep -P -o -m 1 "(?=^ID\=).*" | grep -P -o -m 1 "[a-z]+$")
if [[ ! -z "${OS_ARCH}" ]]; then
	if [[ "${OS_ARCH}" == "arch" ]]; then
		OS_ARCH="x86-64"
	else
		OS_ARCH="aarch64"
	fi
	echo "[info] OS_ARCH defined as '${OS_ARCH}'"
else
	echo "[warn] Unable to identify OS_ARCH, defaulting to 'x86-64'"
	OS_ARCH="x86-64"
fi

# pacman packages
####

echo "[info] Updating pacman database..."
# call pacman db and package updater script
#source upd.sh
printf '%s\n' \
	'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' \
	'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' \
	'Server = https://mirror.leaseweb.net/archlinux/$repo/os/$arch' \
	>/etc/pacman.d/mirrorlist &&
	pacman -Syyu --noconfirm

echo "[info] Installing pacman packages..."
# define pacman packages
pacman_packages="ca-certificates git jq p7zip ipcalc unzip unrar python3 wget python-requests-oauthlib python-markdown python-decorator"

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed $pacman_packages --noconfirm
fi

echo "[info] Installing nzbget..."
# install nzbget
if [[ -z "${NZBGET_SHA256}" ]]; then
	echo "[crit] NZBGET_SHA256 is not set, refusing to install unverified NZBGet release"
	exit 1
fi

wget -O /tmp/nzbget.run "https://github.com/nzbgetcom/nzbget/releases/download/${NZBGET_VERSION_DIR}/nzbget-${NZBGET_VERSION}-bin-linux.run"
printf '%s  %s\n' "${NZBGET_SHA256}" "/tmp/nzbget.run" | sha256sum -c -
sh /tmp/nzbget.run --destdir /usr/sbin/nzbget_bin
ln -s /usr/sbin/nzbget_bin/nzbget /usr/sbin/nzbget

if [[ ! -f /usr/local/bin/shutdown.sh ]]; then
	echo "[info] Installing fallback shutdown script..."
	cat <<'EOF' >/usr/local/bin/shutdown.sh
#!/bin/bash

application="${1:-}"

shutdown() {
	if [[ -n "${application}" ]]; then
		echo "[info] Shutdown signal received, stopping '${application}'..."
		pkill -x "${application}" 2>/dev/null || true
	fi
	exit 0
}

trap shutdown SIGTERM SIGINT

while true; do
	sleep 30
done
EOF
	chmod +x /usr/local/bin/shutdown.sh
fi

# config
####

# container perms
####

# define comma separated list of paths
mkdir -p /data/scripts /data/wireguard-configs /data/openvpn-configs /data/backups
install_paths="/usr/sbin/nzbget_bin,/home/nobody,/data/scripts,/data/wireguard-configs,/data/openvpn-configs,/data/backups"

# split comma separated string into list for install paths
IFS=',' read -ra install_paths_list <<<"${install_paths}"

# process install paths in the list
for i in "${install_paths_list[@]}"; do

	# confirm path(s) exist, if not then exit
	if [[ ! -d "${i}" ]]; then
		echo "[crit] Path '${i}' does not exist, exiting build process..."
		exit 1
	fi

done

# convert comma separated string of install paths to space separated, required for chmod/chown processing
install_paths=$(echo "${install_paths}" | tr ',' ' ')

# set permissions for container during build - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
chmod -R 775 ${install_paths}

cat <<EOF >/tmp/permissions_heredoc
mkdir -p /data/scripts /data/wireguard-configs /data/openvpn-configs /data/backups
mkdir -p /data/scripts/docs /data/scripts/container /data/scripts/shared /data/scripts/notify /data/scripts/host

sync_bundled_script() {
	local source_script="\$1"
	local target_script="\$2"
	local target_dir

	target_dir="\$(dirname -- "\${target_script}")"
	mkdir -p "\${target_dir}"
	if [[ ! -f "\${target_script}" ]]; then
		echo "[info] Installing bundled script '\${target_script}'"
		cp "\${source_script}" "\${target_script}"
		chmod +x "\${target_script}"
	elif ! cmp -s "\${source_script}" "\${target_script}"; then
		echo "[info] Updating bundled script '\${target_script}'"
		cp "\${source_script}" "\${target_script}"
		chmod +x "\${target_script}"
	fi
}

sync_bundled_script_tree() {
	local source_dir="\$1"
	local target_dir="\$2"
	local script_path rel_path

	[[ -d "\${source_dir}" ]] || return 0
	while IFS= read -r -d '' script_path; do
		rel_path="\${script_path#\${source_dir}/}"
		sync_bundled_script "\${script_path}" "\${target_dir}/\${rel_path}"
	done < <(find "\${source_dir}" -type f -name '*.sh' -print0)
}

sync_bundled_script_tree /usr/local/share/nzbgetvpn/scripts/container /data/scripts/container
sync_bundled_script_tree /usr/local/share/nzbgetvpn/scripts/shared /data/scripts/shared
sync_bundled_script_tree /usr/local/share/nzbgetvpn/scripts/notify /data/scripts/notify
sync_bundled_script_tree /usr/local/share/nzbgetvpn/scripts/host /data/scripts/host

# Keep flat /data/scripts/<name>.sh copies for backward compatibility with existing
# VPN_CRON_SCRIPT and VPN_UNHEALTHY_SCRIPT values.
for bundled_script in /usr/local/share/nzbgetvpn/scripts/*.sh; do
	if [[ -f "\${bundled_script}" ]]; then
		target_script="/data/scripts/\$(basename "\${bundled_script}")"
		sync_bundled_script "\${bundled_script}" "\${target_script}"
	fi
done
for bundled_doc in /usr/local/share/nzbgetvpn/scripts/docs/*.md; do
	if [[ -f "\${bundled_doc}" ]]; then
		target_doc="/data/scripts/docs/\$(basename "\${bundled_doc}")"
		if [[ ! -f "\${target_doc}" ]]; then
			echo "[info] Installing bundled script doc '\${target_doc}'"
			cp "\${bundled_doc}" "\${target_doc}"
		elif ! cmp -s "\${bundled_doc}" "\${target_doc}"; then
			echo "[info] Updating bundled script doc '\${target_doc}'"
			cp "\${bundled_doc}" "\${target_doc}"
		fi
	fi
done
if [[ -f /usr/local/share/nzbgetvpn/scripts/README.md && ! -f /data/scripts/README.md ]]; then
	echo "[info] Installing bundled README '/data/scripts/README.md'"
	cp /usr/local/share/nzbgetvpn/scripts/README.md /data/scripts/README.md
fi
if [[ -f /usr/local/share/nzbgetvpn/wireguard-configs/README.md && ! -f /data/wireguard-configs/README.md ]]; then
	echo "[info] Installing bundled README '/data/wireguard-configs/README.md'"
	cp /usr/local/share/nzbgetvpn/wireguard-configs/README.md /data/wireguard-configs/README.md
fi
if [[ -f /usr/local/share/nzbgetvpn/openvpn-configs/README.md && ! -f /data/openvpn-configs/README.md ]]; then
	echo "[info] Installing bundled README '/data/openvpn-configs/README.md'"
	cp /usr/local/share/nzbgetvpn/openvpn-configs/README.md /data/openvpn-configs/README.md
fi
if [[ -f /usr/local/share/nzbgetvpn/backups/README.md && ! -f /data/backups/README.md ]]; then
	echo "[info] Installing bundled README '/data/backups/README.md'"
	cp /usr/local/share/nzbgetvpn/backups/README.md /data/backups/README.md
fi
# get previous puid/pgid (if first run then will be empty string)
previous_puid=\$(cat "/root/puid" 2>/dev/null || true)
previous_pgid=\$(cat "/root/pgid" 2>/dev/null || true)
# if first run (no puid or pgid files in /tmp) or the PUID or PGID env vars are different 
# from the previous run then re-apply chown with current PUID and PGID values.
if [[ ! -f "/root/puid" || ! -f "/root/pgid" || "\${previous_puid}" != "\${PUID}" || "\${previous_pgid}" != "\${PGID}" ]]; then
	# set permissions inside container - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
	chown -R "\${PUID}":"\${PGID}" ${install_paths}
fi
# write out current PUID and PGID to files in /root (used to compare on next run)
echo "\${PUID}" > /root/puid
echo "\${PGID}" > /root/pgid
EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /usr/bin/init.sh
rm /tmp/permissions_heredoc

# env vars
####

cat <<'EOF' >/tmp/envvars_heredoc
export APPLICATION="nzbget"
EOF

# replace env vars placeholder string with contents of file (here doc)
sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /usr/bin/init.sh
rm /tmp/envvars_heredoc

# compatibility patching for inherited scripts
####

# Some base-image scripts still try to load the iptable_mangle kernel module
# directly with modprobe/insmod. On modern kernels this module may not exist
# as a loadable file while mangle support is still available, causing noisy
# startup errors. Replace legacy module load calls with a direct capability
# probe against the mangle table.
echo "[info] Applying iptable_mangle compatibility patch to inherited scripts..."
for script_path in /root/*.sh /usr/bin/*.sh /home/nobody/*.sh; do
	if [[ -f "${script_path}" ]] && grep -q "iptable_mangle" "${script_path}" 2>/dev/null; then
		sed -i \
			-e 's~modprobe[[:space:]]\+iptable_mangle~iptables -t mangle -S >\/dev\/null 2>\&1~g' \
			-e 's~insmod[[:space:]]\+\/lib\/modules\/iptable_mangle\.ko~iptables -t mangle -S >\/dev\/null 2>\&1~g' \
			"${script_path}"
	fi
done

# cleanup
cleanup.sh
