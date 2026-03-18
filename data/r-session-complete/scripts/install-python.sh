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

mkdir -p /etc/uv
cat << EOF > /etc/uv/uv.toml
[[index]]
url = "https://packagemanager.posit.co/pypi/latest/simple"
default = true
EOF

for PYTHON_VERSION in ${PYTHON_VERSION_LIST}
do
    /usr/local/bin/uv pip install --break-system-packages --upgrade \
        --python /opt/python/${PYTHON_VERSION}/bin/python \
        pip setuptools wheel && \
    /usr/local/bin/uv pip install --break-system-packages \
        --python /opt/python/${PYTHON_VERSION}/bin/python \
        ipykernel \
        jupyter \
        rsconnect_python \
        rsp_jupyter \
        notebook=="6.1.5" \
        beautifulsoup4=="4.14.3" \
        "jupyterlab~=4.2.4" \
        "pwb_jupyterlab~=1.0" && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension install --sys-prefix --py rsp_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension enable --sys-prefix --py rsp_jupyter && \
    /opt/python/${PYTHON_VERSION}/bin/python -m ipykernel install --name py${PYTHON_VERSION} --display-name "Python ${PYTHON_VERSION}" & 
done
wait

# Use default version to point to jupyter and python 
if [ ! -z ${PYTHON_VERSION_DEFAULT} ]; then
    ln -s /opt/python/${PYTHON_VERSION_DEFAULT}/bin/jupyter /usr/local/bin
    ln -s /opt/python/${PYTHON_VERSION_DEFAULT}/bin/python /usr/local/bin
    ln -s /opt/python/${PYTHON_VERSION_DEFAULT}/bin/python3 /usr/local/bin
fi