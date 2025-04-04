#!/bin/bash

# Install TeXlive 

curl -LO https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    tar xvfz install-tl-unx.tar.gz && \
    rm install-tl-unx.tar.gz && \
    cd install-tl-* && \
    ./install-tl --scheme small --no-interaction #--repository ftp://tug.org/historic/systems/texlive/${TEXLIVE_VERSION}/tlnet-final

TEXLIVE_VERSION=`ls /usr/local/texlive/ | grep [0-9]`

echo "export PATH=/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux:\$PATH" > /etc/profile.d/texlive.sh
