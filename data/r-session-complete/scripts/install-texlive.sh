#!/bin/bash

# Install TeXlive
# Optionally set TEXLIVE_MIRROR to a CTAN mirror URL
# (e.g. https://mirror.example.org/CTAN/systems/texlive/tlnet)
# If unset, the default CTAN mirror redirector is used.

MIRROR_OPT=${TEXLIVE_MIRROR:+--repository ${TEXLIVE_MIRROR}}

curl -LO https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    tar xvfz install-tl-unx.tar.gz && \
    rm install-tl-unx.tar.gz && \
    cd install-tl-* && \
    ./install-tl --scheme small --no-interaction ${MIRROR_OPT}

TEXLIVE_VERSION=`ls /usr/local/texlive/ | grep [0-9]`


# Add environment variables so that user space installs of additional texlive packages work.
cat > /etc/profile.d/texlive.sh << EOF
export PATH=/usr/local/bin:/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux:\$PATH
# User-writable TEXMF trees so tlmgr install works without root
export TEXMFHOME=\$HOME/texmf
export TEXMFCONFIG=\$HOME/.texlive/texmf-config
export TEXMFVAR=\$HOME/.texlive/texmf-var
EOF

# Install a real tlmgr wrapper script in /usr/local/bin so that non-root users
# get --usermode automatically, including from tools like texliveonfly (Perl).
cat > /usr/local/bin/tlmgr << 'WRAPPER'
#!/bin/bash
REAL_TLMGR=$(ls -d /usr/local/texlive/20*/bin/x86_64-linux/tlmgr 2>/dev/null | head -1)
if [ "$(id -u)" != "0" ]; then
    [ -d "${TEXMFHOME:-$HOME/texmf}" ] || "$REAL_TLMGR" init-usertree
    exec "$REAL_TLMGR" --usermode "$@"
else
    exec "$REAL_TLMGR" "$@"
fi
WRAPPER
chmod +x /usr/local/bin/tlmgr

# Pin tlmgr to the same mirror if one was specified
if [ -n "${TEXLIVE_MIRROR}" ]; then
    /usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux/tlmgr option repository ${TEXLIVE_MIRROR}
fi

# Install texliveonfly so it can help with auto-install missing packages
/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux/tlmgr install texliveonfly
