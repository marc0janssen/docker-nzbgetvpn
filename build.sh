#!/bin/sh

# Name: docker-nzbgetvpn
# Coder: Marco Janssen (micro.blog @marc0janssen https://micro.mjanssen.nl)
# date: 2021-11-28 14:24:26
# update: 2021-11-28 14:24:32

VERSION_FILE=".version"

# Read release number from file
VERSION=$(cat ${VERSION_FILE})

# Change new releasenumber in files
sed -i '' "s/NZBGET Current stable version: .*/\NZBGET Current stable version: ${VERSION}/" ./README.md
sed -i '' "s/NZBGET_VERSION=.*/\NZBGET_VERSION=${VERSION}/" ./Dockerfile
sed -i '' "s/NZBGET_VERSION_DIR=.*/\NZBGET_VERSION_DIR=${VERSION}/" ./Dockerfile

docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push -t marc0janssen/nzbgetvpn:stable -f ./Dockerfile .
docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push -t marc0janssen/nzbgetvpn:${VERSION} -f ./Dockerfile .

docker pushrm marc0janssen/nzbgetvpn:stable
