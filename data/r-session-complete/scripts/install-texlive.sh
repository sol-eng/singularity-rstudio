#!/bin/bash

# Install TeXlive 

curl -LO https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    tar xvfz install-tl-unx.tar.gz && \
    rm install-tl-unx.tar.gz && \
    cd install-tl-* && \
    ./install-tl --scheme small --no-interaction #--repository ftp://tug.org/historic/systems/texlive/${TEXLIVE_VERSION}/tlnet-final

TEXLIVE_VERSION=`ls /usr/local/texlive/ | grep [0-9]`


# Add environment variables so that user space installa of additional texlive packages work. 
# Also ensure that tlmgr calls for non-root users use --usermode 
cat > /etc/profile.d/texlive.sh << EOF
export PATH=/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux:\$PATH
# User-writable TEXMF trees so tlmgr install works without root
export TEXMFHOME=\$HOME/texmf
export TEXMFCONFIG=\$HOME/.texlive/texmf-config
export TEXMFVAR=\$HOME/.texlive/texmf-var
# For non-root users, default tlmgr to user mode and init the user tree on first use
tlmgr() {
    if [ "\$(id -u)" != "0" ]; then
        [ -d "\$TEXMFHOME" ] || command tlmgr init-usertree
        command tlmgr --usermode "\$@"
    else
        command tlmgr "\$@"
    fi
}
export -f tlmgr
EOF
