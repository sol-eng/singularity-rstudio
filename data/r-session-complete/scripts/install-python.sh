#!/bin/bash

PYTHON_VERSION_LIST=${@: 4:$#}
PYTHON_VERSION_DEFAULT=${@: 3:1}
PKG_TYPE=${@: 1:1}
DISTRO=${@: 2:1}

echo $DISTRO
echo $PKG_TYPE

set -x
for PYTHON_VERSION in ${PYTHON_VERSION_LIST}
    do
        case $PKG_TYPE in
            "deb")
                curl -O https://cdn.rstudio.com/python/${DISTRO}/pkgs/python-${PYTHON_VERSION}_1_amd64.deb
                gdebi -n python-${PYTHON_VERSION}_1_amd64.deb
                rm -f python-${PYTHON_VERSION}_1_amd64.deb
                ;;
            "rpm")
                yum install -y https://cdn.rstudio.com/python/${DISTRO}/pkgs/python-${PYTHON_VERSION}-1-1.x86_64.rpm
                ;;
            *)
                echo "Unsupported package type: $PKG_TYPE"
                exit 1
                ;;
        esac
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
        pip setuptools wheel && \
    /opt/python/${PYTHON_VERSION}/bin/pip install \
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