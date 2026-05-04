#FROM binhex/arch-int-vpn:2025100101
FROM binhex/arch-int-vpn:latest

ENV NZBGET_VERSION=26.1
ENV NZBGET_VERSION_DIR=v26.1
ENV NZBGET_SHA256=d91c3268adebc1ef826c28d591b143963b3ec559c1e9eb4a6e6dae503d34e769

# additional files
##################

# add supervisor conf file for app
ADD build/*.conf /etc/supervisor/conf.d/

# add bash scripts to install app
ADD build/root/*.sh /root/

# add run bash scripts
ADD run/root/*.sh /root/

# add run bash scripts
ADD run/nobody/*.sh /home/nobody/

# add bundled user script templates
ADD data/scripts/*.sh /usr/local/share/nzbgetvpn/scripts/
ADD data/scripts/README.md /usr/local/share/nzbgetvpn/scripts/README.md
ADD data/wireguard-configs/README.md /usr/local/share/nzbgetvpn/wireguard-configs/README.md
ADD data/openvpn-configs/README.md /usr/local/share/nzbgetvpn/openvpn-configs/README.md

# install app
#############

# make executable and run bash scripts to install app
RUN chmod +x /root/*.sh /home/nobody/*.sh /usr/local/share/nzbgetvpn/scripts/*.sh && /bin/bash /root/install.sh

# docker settings
#################

# map /config to host defined config path (used to store configuration from app)
VOLUME /config

# map /data to host defined data path (used to store data from app)
VOLUME /data

# expose port for http
EXPOSE 6789

# set permissions
#################

# run script to set uid, gid and permissions
CMD ["/bin/bash", "/usr/bin/init.sh"]
