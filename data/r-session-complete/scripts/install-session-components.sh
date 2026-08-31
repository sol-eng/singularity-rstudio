#!/bin/bash

DISTRO=$1
PWB_VERSION=$2
ARCH=$3

echo ""
echo "====================================================================="
echo "STAGE: Installing Workbench session components for  $PWB_VERSION..."
echo "====================================================================="
echo ""

mkdir -p /usr/lib/rstudio-server
curl -O https://s3.amazonaws.com/rstudio-ide-build/session/${DISTRO}/${ARCH}/rsp-session-${DISTRO}-${PWB_VERSION}-${ARCH}.tar.gz
tar xfz rsp-session-${DISTRO}-${PWB_VERSION}-${ARCH}.tar.gz -C /usr/lib/rstudio-server --strip=1
rm -f rsp-session-${DISTRO}-${PWB_VERSION}-${ARCH}.tar.gz


echo ""
echo "====================================================================="
echo "STAGE: Workbench session components for $PWB_VERSION installation finished..."
echo "====================================================================="
echo ""