#!/bin/bash

DISTRO=$1
PWB_VERSION=$2

mkdir -p /usr/lib/rstudio-server
curl -O https://s3.amazonaws.com/rstudio-ide-build/session/focal/amd64/rsp-session-${DISTRO}-${PWB_VERSION}-amd64.tar.gz
tar xfz rsp-session-${DISTRO}-${PWB_VERSION}-amd64.tar.gz -C /usr/lib/rstudio-server --strip=1
rm -f rsp-session-${DISTRO}-${PWB_VERSION}-amd64.tar.gz