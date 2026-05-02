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
  > /etc/pacman.d/mirrorlist \
  && pacman -Syyu --noconfirm



echo "[info] Installing pacman packages..."
# define pacman packages
pacman_packages="git p7zip ipcalc unzip unrar python3 wget python-requests-oauthlib python-markdown python-decorator"

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed $pacman_packages --noconfirm
fi


echo "[info] Installing nzbget..."
# install nzbget
if [[ -z "${NZBGET_SHA256}" ]]; then
	echo "[crit] NZBGET_SHA256 is not set, refusing to install unverified NZBGet release" ; exit 1
fi

wget -O /tmp/nzbget.run "https://github.com/nzbgetcom/nzbget/releases/download/${NZBGET_VERSION_DIR}/nzbget-${NZBGET_VERSION}-bin-linux.run"
printf '%s  %s\n' "${NZBGET_SHA256}" "/tmp/nzbget.run" | sha256sum -c -
sh /tmp/nzbget.run --destdir /usr/sbin/nzbget_bin
ln -s /usr/sbin/nzbget_bin/nzbget /usr/sbin/nzbget


# Install new certificate file
if [[ -z "${NZBGET_CACERT_SHA256}" ]]; then
	echo "[crit] NZBGET_CACERT_SHA256 is not set, refusing to install unverified certificate store" ; exit 1
fi

wget -O /usr/sbin/nzbget_bin/cacert.pem https://nzbget.net/info/cacert.pem
printf '%s  %s\n' "${NZBGET_CACERT_SHA256}" "/usr/sbin/nzbget_bin/cacert.pem" | sha256sum -c -

# config
####

# container perms
####

# define comma separated list of paths 
install_paths="/usr/sbin/nzbget_bin,/home/nobody"

# split comma separated string into list for install paths
IFS=',' read -ra install_paths_list <<< "${install_paths}"

# process install paths in the list
for i in "${install_paths_list[@]}"; do

	# confirm path(s) exist, if not then exit
	if [[ ! -d "${i}" ]]; then
		echo "[crit] Path '${i}' does not exist, exiting build process..." ; exit 1
	fi

done

# convert comma separated string of install paths to space separated, required for chmod/chown processing
install_paths=$(echo "${install_paths}" | tr ',' ' ')

# set permissions for container during build - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
chmod -R 775 ${install_paths}

cat <<EOF > /tmp/permissions_heredoc
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

cat <<'EOF' > /tmp/envvars_heredoc
export APPLICATION="nzbget"
EOF

# replace env vars placeholder string with contents of file (here doc)
sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /usr/bin/init.sh
rm /tmp/envvars_heredoc

# cleanup
cleanup.sh
