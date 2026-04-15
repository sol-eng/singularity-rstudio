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
    # Explicitly set TEXMF paths so they are consistent regardless of whether
    # /etc/profile.d/texlive.sh was sourced (e.g. when called from a Quarto
    # subprocess). Without this, tlmgr --usermode falls back to version-stamped
    # paths (~/.texlive2026/) while kpathsea looks in ~/texmf — files are
    # installed to the wrong location and TeX still reports them as missing.
    export TEXMFHOME="${TEXMFHOME:-$HOME/texmf}"
    export TEXMFCONFIG="${TEXMFCONFIG:-$HOME/.texlive/texmf-config}"
    export TEXMFVAR="${TEXMFVAR:-$HOME/.texlive/texmf-var}"

    # Read-only operations must NOT use --usermode: they need access to the full
    # package catalog. Without this, Quarto's "search --file foo.sty" returns
    # "no matching packages" and auto-install silently fails.
    case "$1" in
        search|info|list|check|version|print-platform*)
            exec "$REAL_TLMGR" "$@"
            ;;
    esac
    [ -d "$TEXMFHOME" ] || "$REAL_TLMGR" init-usertree
    # Skip self-update and full package updates in user mode:
    # - update --self is a no-op (users can't update the tlmgr binary)
    # - update --all is very slow and is an admin concern, not a user one
    # Quarto triggers both before installing missing packages; suppressing them
    # here keeps auto-install fast.
    if [ "$1" = "update" ]; then
        shift
        args=()
        for arg in "$@"; do
            case "$arg" in
                --self|--all) ;;
                *) args+=("$arg") ;;
            esac
        done
        [ ${#args[@]} -eq 0 ] && exit 0
        exec "$REAL_TLMGR" --usermode update "${args[@]}"
    fi
    # After installing packages, rebuild the kpathsea filename database in the
    # user tree so lualatex/pdflatex can find the newly installed .sty files.
    if [ "$1" = "install" ]; then
        "$REAL_TLMGR" --usermode "$@"
        STATUS=$?
        [ $STATUS -eq 0 ] && mktexlsr "$TEXMFHOME" 2>/dev/null
        exit $STATUS
    fi
    exec "$REAL_TLMGR" --usermode "$@"
else
    exec "$REAL_TLMGR" "$@"
fi
WRAPPER
chmod +x /usr/local/bin/tlmgr

# Wrapper for fmtutil-sys: non-root users cannot write to the system format tree.
# Redirect to fmtutil-user, which rebuilds formats into $TEXMFVAR instead.
# Quarto calls fmtutil-sys --all after installing packages via tlmgr.
cat > /usr/local/bin/fmtutil-sys << 'WRAPPER'
#!/bin/bash
REAL_FMTUTIL=$(ls -d /usr/local/texlive/20*/bin/x86_64-linux/fmtutil-sys 2>/dev/null | head -1)
if [ "$(id -u)" != "0" ]; then
    exec "$(dirname $REAL_FMTUTIL)/fmtutil-user" "$@"
else
    exec "$REAL_FMTUTIL" "$@"
fi
WRAPPER
chmod +x /usr/local/bin/fmtutil-sys

# Pin tlmgr to the same mirror if one was specified
if [ -n "${TEXLIVE_MIRROR}" ]; then
    /usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux/tlmgr option repository ${TEXLIVE_MIRROR}
fi

# Install texliveonfly so it can help with auto-install missing packages.
# Also pre-install framed (needed by Quarto's default PDF callout boxes and
# commonly required by knitr/rmarkdown documents).
/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux/tlmgr install texliveonfly

# Pre-generate the lualatex font database so the first user render is not slow.
# luaotfload otherwise generates this on-demand, which can take several minutes.
/usr/local/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux/luaotfload-tool --update
