#!/bin/bash

PKG_TYPE=$1
PRO_DRIVERS_VERSION=$2

echo "Installing Pro Drivers $PRO_DRIVERS_VERSION..."
case $PKG_TYPE in
    "deb")
    curl -O https://cdn.rstudio.com/drivers/7C152C12/installer/rstudio-drivers_${PRO_DRIVERS_VERSION}_amd64.deb && \
        gdebi -n rstudio-drivers_${PRO_DRIVERS_VERSION}_amd64.deb && \
        rm -f rstudio-drivers_${PRO_DRIVERS_VERSION}_amd64.deb
        ;;
    "rpm")
        yum -y install https://cdn.rstudio.com/drivers/7C152C12/installer/rstudio-drivers-${PRO_DRIVERS_VERSION}-1.el.x86_64.rpm
        ;;
    *)
        echo "Unsupported package type: $PKG_TYPE"
        exit 1
    ;;
esac    