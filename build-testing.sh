#!/bin/sh

# Name: docker-nzbgetvpn
# Coder: Marco Janssen (micro.blog @marc0janssen https://micro.mjanssen.nl)
# date: 2021-11-28 14:24:26
# update: 2021-11-28 14:24:32

VERSION_FILE=".testing"

# Read release number from file
VERSION=$(cat ${VERSION_FILE})

# Change new releasenumber in files
sed -i '' "s/NZBGET Current testing version: .*/\NZBGET Current testing version: ${VERSION}/" ./README.md
sed -i '' "s/NZBGET_VERSION=.*/\NZBGET_VERSION=${VERSION}/" ./Dockerfile-testing

docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push -t marc0janssen/nzbgetvpn:${VERSION} -t marc0janssen/nzbgetvpn:testing -f ./Dockerfile-testing .
#docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push -t marc0janssen/nzbgetvpn:${VERSION} -f ./Dockerfile-testing .

#docker buildx build --no-cache --platform linux/amd64 --push -t marc0janssen/nzbgetvpn:testing -f ./Dockerfile-testing .
#docker buildx build --no-cache --platform linux/amd64 --push -t marc0janssen/nzbgetvpn:${VERSION} -f ./Dockerfile-testing .

docker pushrm marc0janssen/nzbgetvpn:testing
