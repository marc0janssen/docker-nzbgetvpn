#!/bin/sh

# Name: docker-nzbgetvpn
# Coder: Marco Janssen (twitter @marc0janssen)
# date: 2021-11-28 14:24:26
# update: 2021-11-28 14:24:32

docker image rm marc0janssen/docker-nzbgetvpn:latest

# docker build -t marc0janssen/docker-nzbgetvpn -f ./Dockerfile .
# docker push marc0janssen/docker-nzbgetvpn:latest

docker buildx build --platform linux/amd64,linux/arm64 --push -t marc0janssen/docker-nzbgetvpn -f ./Dockerfile .

docker pushrm marc0janssen/docker-nzbgetvpn:latest
