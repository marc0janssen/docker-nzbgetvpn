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

bundled_sync_policy="\${BUNDLED_SYNC_POLICY:-smart}"
case "\${bundled_sync_policy}" in
smart | force | preserve)
	;;
*)
	echo "[warn] Invalid BUNDLED_SYNC_POLICY='\${bundled_sync_policy}', falling back to 'smart'"
	bundled_sync_policy="smart"
	;;
esac
if [[ "\${bundled_sync_policy}" == "preserve" ]]; then
	echo "[warn] BUNDLED_SYNC_POLICY=preserve enabled; bundled file updates are skipped and this can cause runtime drift or break behavior after image upgrades"
fi

has_preserve_marker() {
	local target_file="\$1"
	[[ -f "\${target_file}" ]] || return 1
	grep -Eiq 'nzbgetvpn[[:space:]]*:[[:space:]]*preserve-local' "\${target_file}" 2>/dev/null
}

sync_bundled_file() {
	local source_path="\$1"
	local target_path="\$2"
	local label="\$3"
	local mode="\${4:-}"
	local marker_policy="\${5:-allow}"
	local target_dir preserve_reason

	[[ -f "\${source_path}" ]] || return 0
	target_dir="\$(dirname -- "\${target_path}")"
	mkdir -p "\${target_dir}"

	if [[ ! -f "\${target_path}" ]]; then
		echo "[info] Installing bundled \${label} '\${target_path}'"
		cp "\${source_path}" "\${target_path}"
		if [[ -n "\${mode}" ]]; then
			chmod "\${mode}" "\${target_path}"
		fi
		return 0
	fi

	if cmp -s "\${source_path}" "\${target_path}"; then
		if [[ -n "\${mode}" ]]; then
			chmod "\${mode}" "\${target_path}"
		fi
		return 0
	fi

	preserve_reason=""
	if [[ "\${bundled_sync_policy}" == "preserve" ]]; then
		preserve_reason="BUNDLED_SYNC_POLICY=preserve"
	elif [[ "\${bundled_sync_policy}" == "smart" && "\${marker_policy}" == "allow" ]] && has_preserve_marker "\${target_path}"; then
		preserve_reason="preserve marker"
	fi

	if [[ -n "\${preserve_reason}" ]]; then
		echo "[warn] Preserving local '\${target_path}' due to \${preserve_reason}; bundled update skipped and this can break compatibility after upgrades"
		return 0
	fi

	echo "[info] Updating bundled \${label} '\${target_path}'"
	cp "\${source_path}" "\${target_path}"
	if [[ -n "\${mode}" ]]; then
		chmod "\${mode}" "\${target_path}"
	fi
}

sync_bundled_script_tree() {
	local source_dir="\$1"
	local target_dir="\$2"
	local script_path rel_path

	[[ -d "\${source_dir}" ]] || return 0
	while IFS= read -r -d '' script_path; do
		rel_path="\${script_path#\${source_dir}/}"
		sync_bundled_file "\${script_path}" "\${target_dir}/\${rel_path}" "script" "755" "allow"
	done < <(find "\${source_dir}" -type f -name '*.sh' -print0)
}

sync_bundled_script_tree /usr/local/share/nzbgetvpn/scripts/container /data/scripts/container
sync_bundled_script_tree /usr/local/share/nzbgetvpn/scripts/shared /data/scripts/shared
sync_bundled_script_tree /usr/local/share/nzbgetvpn/scripts/notify /data/scripts/notify
sync_bundled_script_tree /usr/local/share/nzbgetvpn/scripts/host /data/scripts/host
sync_bundled_file /usr/local/share/nzbgetvpn/scripts/lib.sh /data/scripts/lib.sh "script library" "" "allow"

# Remove legacy flat bundled script copies from /data/scripts root.
# Keep subfolders (/data/scripts/{container,shared,notify,host}) as the
# supported location for bundled helper scripts.
for legacy_flat_script in \
	/data/scripts/doctor.sh \
	/data/scripts/get_wireguard_configs_nordvpn.sh \
	/data/scripts/rotate_on_poor_speed.sh \
	/data/scripts/select_random_openvpn_config.sh \
	/data/scripts/select_random_wireguard_config.sh \
	/data/scripts/backup_config.sh \
	/data/scripts/benchmark_endpoints.sh \
	/data/scripts/log_sanitizer.sh \
	/data/scripts/upgrade_check.sh \
	/data/scripts/notify_discord.sh \
	/data/scripts/notify_telegram.sh \
	/data/scripts/notify_pushover.sh \
	/data/scripts/run-container-helper.sh; do
	if [[ -f "\${legacy_flat_script}" ]]; then
		echo "[info] Removing legacy flat bundled script '\${legacy_flat_script}'"
		rm -f -- "\${legacy_flat_script}"
	fi
done
for bundled_doc in /usr/local/share/nzbgetvpn/scripts/docs/*.md; do
	if [[ -f "\${bundled_doc}" ]]; then
		target_doc="/data/scripts/docs/\$(basename "\${bundled_doc}")"
		sync_bundled_file "\${bundled_doc}" "\${target_doc}" "script doc" "" "ignore"
	fi
done
sync_bundled_file /usr/local/share/nzbgetvpn/scripts/README.md /data/scripts/README.md "README" "" "ignore"
sync_bundled_file /usr/local/share/nzbgetvpn/wireguard-configs/README.md /data/wireguard-configs/README.md "README" "" "ignore"
sync_bundled_file /usr/local/share/nzbgetvpn/openvpn-configs/README.md /data/openvpn-configs/README.md "README" "" "ignore"
sync_bundled_file /usr/local/share/nzbgetvpn/backups/README.md /data/backups/README.md "README" "" "ignore"
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
