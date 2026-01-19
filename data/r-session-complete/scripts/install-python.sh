#!/bin/bash

PYTHON_VERSION_LIST=${@: 4:$#}
PYTHON_VERSION_DEFAULT=${@: 3:1}
PKG_TYPE=${@: 1:1}
DISTRO=${@: 2:1}

echo $DISTRO
echo $PKG_TYPE

curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

set -x
for PYTHON_VERSION in ${PYTHON_VERSION_LIST}
    do
        /usr/local/bin/uv python install "${PYTHON_VERSION}" --install-dir=/opt/python
        ln -s /opt/python/cpython-$PYTHON_VERSION-* /opt/python/$PYTHON_VERSION

    done

# Configure Python versions to have 
#  - upgraded pip 
#  - configure pip to use posit package manager 
#  - preinstalling packages needed for the integration with other tools (e.g Connect) 
# Note: Install will run in parallel to speed up things

cat << EOF > /etc/pip.conf
[global]
timeout = 60
index-url = https://packagemanager.posit.co/pypi/latest/simple
EOF

for PYTHON_VERSION in ${PYTHON_VERSION_LIST}
do
    /opt/python/${PYTHON_VERSION}/bin/pip install --upgrade \
        --break-system-packages \
        --root-user-action=ignore \
        pip setuptools wheel && \
    /opt/python/${PYTHON_VERSION}/bin/pip install \
        --break-system-packages \
        --root-user-action=ignore \
        ipykernel \
        jupyter \
        rsconnect_jupyter \
        rsconnect_python \
        rsp_jupyter \
        jupyterlab~=4.2.4 \
        pwb_jupyterlab~=1.0 && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension install --sys-prefix --py rsp_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension enable --sys-prefix --py rsp_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension install --sys-prefix --py rsconnect_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension enable --sys-prefix --py rsconnect_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-serverextension enable --sys-prefix --py rsconnect_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/python -m ipykernel install --name py${PYTHON_VERSION} --display-name "Python ${PYTHON_VERSION}" & 
done
wait

# Use default version to point to jupyter and python 
if [ ! -z ${PYTHON_VERSION_DEFAULT} ]; then
    ln -s /opt/python/${PYTHON_VERSION_DEFAULT}/bin/jupyter /usr/local/bin
    ln -s /opt/python/${PYTHON_VERSION_DEFAULT}/bin/python /usr/local/bin
    ln -s /opt/python/${PYTHON_VERSION_DEFAULT}/bin/python3 /usr/local/bin
fi