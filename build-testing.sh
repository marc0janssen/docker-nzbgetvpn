#!/bin/sh

# Name: docker-nzbgetvpn
# Coder: Marco Janssen (twitter @marc0janssen)
# date: 2021-11-28 14:24:26
# update: 2021-11-28 14:24:32

VERSION="22.2-testing-20240209"

docker image rm marc0janssen/nzbgetvpn:testing
docker image rm marc0janssen/nzbgetvpn:${VERSION}

# docker build -t marc0janssen/docker-nzbgetvpn -f ./Dockerfile .
# docker push marc0janssen/docker-nzbgetvpn:latest

docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push -t marc0janssen/nzbgetvpn:testing -f ./Dockerfile-testing .
docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push -t marc0janssen/nzbgetvpn:${VERSION} -f ./Dockerfile-testing .

docker pushrm marc0janssen/nzbgetvpn:testing
