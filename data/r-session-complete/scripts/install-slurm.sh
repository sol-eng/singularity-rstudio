#!/bin/bash

SLURM_VERSION=$1

groupadd -g 401 slurm
useradd -u 401 -g 401 slurm

# Note that the git branches on github do have a slightly different
# naming scheme - firstly the dots are replaced by dashes and
# secondly each SLURM version can have more than one release tag
# Here, we simply append "-1" to use the first git tag of a given
# SLURM version

dir=`mktemp -d` && \
    cd $dir && \
    rm -rf slurm && \
    export SLURM_VER=${SLURM_VERSION} && git clone --depth 1 -b slurm-${SLURM_VER//./-}-1 https://github.com/SchedMD/slurm.git && \
    cd slurm && \
    ./configure --prefix /usr/local/slurm > /var/log/slurm-configure.log && \
    echo "Compiling SLURM" && \
    make -j 4 > /var/log/slurm-compile.log && \
    echo "Installing SLURM" && \
    make install > /var/log/slurm-install.log && \
    cd / && \
    rm -rf $dir && \
    ln -s /usr/local/slurm/bin/* /usr/local/bin