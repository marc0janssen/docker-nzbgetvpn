FROM binhex/arch-int-vpn:2025070701

ENV NZBGET_VERSION=25.2
ENV NZBGET_VERSION_DIR=v25.2

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

# install app
#############

# make executable and run bash scripts to install app
RUN chmod +x /root/*.sh /home/nobody/*.sh && \
	/bin/bash /root/install.sh

# Replace default CA certificate store with updated one
COPY build/cacert.pem /usr/sbin/nzbget_bin/

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
