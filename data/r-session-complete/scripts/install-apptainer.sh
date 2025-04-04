#!/bin/bash

PKG_TYPE=$1
APPTAINER_VERSION=$2

dir=`mktemp -d`
cd $dir

echo "Installing Apptainer $APPTAINER_VERSION..."
case $PKG_TYPE in
    "deb")
        curl -L -O https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer_${APPTAINER_VERSION}_amd64.deb
        curl -L -O https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-suid_${APPTAINER_VERSION}_amd64.deb
        gdebi -n apptainer_${APPTAINER_VERSION}_amd64.deb
        gdebi -n apptainer-suid_${APPTAINER_VERSION}_amd64.deb
        ;;
    "rpm")
        curl -L -O https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-${APPTAINER_VERSION}-1.x86_64.rpm
        curl -L -O https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-suid-${APPTAINER_VERSION}-1.x86_64.rpm
        yum install -y /usr/*bin/fuse2fs
        yum localinstall -y apptainer-${APPTAINER_VERSION}-1.x86_64.rpm
        yum localinstall -y apptainer-suid-${APPTAINER_VERSION}-1.x86_64.rpm
        ;;
    *)
        echo "Unsupported package type: $PKG_TYPE"
        exit 1
        ;;
esac

cd ..

rm -rf $dir

