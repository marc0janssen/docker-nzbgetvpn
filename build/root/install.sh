#!/usr/bin/env bash

set -euo pipefail

log() {
    local level="$1"
    shift
    printf '[%s] %s\n' "$level" "$*"
}

detect_arch() {
    local id
    id=$(awk -F= '$1=="ID" {gsub(/"/, "", $2); print $2}' /etc/os-release || true)
    case "$id" in
        arch)
            printf 'x86-64'
            ;;
        "")
            log warn "Unable to identify OS architecture, defaulting to 'x86-64'"
            printf 'x86-64'
            ;;
        *)
            printf 'aarch64'
            ;;
    esac
}

OS_ARCH=$(detect_arch)
log info "OS_ARCH defined as '${OS_ARCH}'"

log info 'Refreshing pacman database and upgrading base packages'
pacman -Syu --noconfirm

pacman_packages=(
    git
    p7zip
    ipcalc
    unzip
    unrar
    python3
    wget
    python-requests-oauthlib
    python-markdown
    python-decorator
)

if ((${#pacman_packages[@]} > 0)); then
    log info 'Installing required pacman packages'
    pacman -S --needed --noconfirm "${pacman_packages[@]}"
fi

aur_helper='/root/aur.sh'
if [[ -f ${aur_helper} ]]; then
    # shellcheck disable=SC1090
    source "${aur_helper}"
else
    log warn 'AUR helper script not found, skipping AUR installation phase'
fi

nzbget_run='/tmp/nzbget.run'
nzbget_url="https://github.com/nzbgetcom/nzbget/releases/download/${NZBGET_VERSION_DIR}/nzbget-${NZBGET_VERSION}-bin-linux.run"
log info "Downloading nzbget from ${nzbget_url}"
wget -q -O "${nzbget_run}" "${nzbget_url}"
sh "${nzbget_run}" --destdir /usr/sbin/nzbget_bin
ln -sf /usr/sbin/nzbget_bin/nzbget /usr/sbin/nzbget

log info 'Downloading updated certificate bundle'
wget -q -O /usr/sbin/nzbget_bin/cacert.pem https://nzbget.net/info/cacert.pem

install_paths=(/usr/sbin/nzbget_bin /home/nobody)
for path in "${install_paths[@]}"; do
    if [[ ! -d ${path} ]]; then
        log crit "Path '${path}' does not exist, exiting build process"
        exit 1
    fi
    chmod -R 775 "${path}"
done

cat <<'PERMISSIONS' > /tmp/permissions_heredoc
previous_puid=$(cat '/root/puid' 2>/dev/null || true)
previous_pgid=$(cat '/root/pgid' 2>/dev/null || true)
if [[ ! -f '/root/puid' || ! -f '/root/pgid' || "${previous_puid}" != "${PUID}" || "${previous_pgid}" != "${PGID}" ]]; then
        chown -R "${PUID}":"${PGID}" /usr/sbin/nzbget_bin /home/nobody
fi
echo "${PUID}" > /root/puid
echo "${PGID}" > /root/pgid
PERMISSIONS

sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /usr/bin/init.sh
rm /tmp/permissions_heredoc

cat <<'ENVVARS' > /tmp/envvars_heredoc
export APPLICATION="nzbget"
ENVVARS

sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /usr/bin/init.sh
rm /tmp/envvars_heredoc

cleanup.sh
