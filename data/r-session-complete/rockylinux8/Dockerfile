FROM rockylinux:8

# needed if you want to set up CRAN and BioConductor repos from RSPM (optional)
# set binaryflag to "" in order to stick to source RPMs
COPY scripts/run.R /
COPY scripts/bioc.txt / 
COPY scripts/r-packages.txt /

# Activate EPEL Release and powertools

RUN yum -y install yum-utils epel-release && yum-config-manager --enable powertools 

# Set up of gcc toolset 14 to use a more recent version of the 
# compiler toolchain 
RUN yum -y install gcc-toolset-14

# Install Pro Drivers

ARG PRO_DRIVERS_VERSION

RUN yum install -y \
        https://cdn.rstudio.com/drivers/7C152C12/installer/rstudio-drivers-${PRO_DRIVERS_VERSION}-1.el.x86_64.rpm \
        && cp -f /opt/rstudio-drivers/odbcinst.ini.sample /etc/odbcinst.ini


# Install TeXlive 

RUN yum install -y perl
RUN curl -LO https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
        tar xvfz install-tl-unx.tar.gz && \
        rm install-tl-unx.tar.gz && \
        cd install-tl-* && \
        ./install-tl --scheme small --no-interaction  -repo https://mirror.ox.ac.uk/sites/ctan.org/systems/texlive/tlnet
    # -repo https://mirror.init7.net/ctan/systems/texlive/tlnet

RUN echo "export PATH=/usr/local/texlive/2024/bin/x86_64-linux:\$PATH" > /etc/profile.d/texlive.sh


# Install Quarto
ARG QUARTO_VERSION
RUN curl -o quarto.tar.gz -L https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.tar.gz \
    && mkdir -p /opt/quarto/${QUARTO_VERSION} \
    && tar -zxf quarto.tar.gz -C "/opt/quarto/${QUARTO_VERSION}" --strip-components=1 \
    && rm -f quarto.tar.gz \
    && ln -s /opt/quarto/${QUARTO_VERSION}/bin/quarto /usr/local/bin/quarto


# Install Python 

ARG PYTHON_VERSION_LIST
RUN for PYTHON_VERSION in ${PYTHON_VERSION_LIST} ;\
    do \
        yum install -y https://cdn.rstudio.com/python/centos-8/pkgs/python-${PYTHON_VERSION}-1-1.x86_64.rpm ; \
    done

    # Configure Python versions to have 
    #  - upgraded pip 
    #  - configure pip to use posit package manager 
    #  - preinstalling packages needed for the integration with other tools (e.g Connect) 
    # Note: Install will run in parallel to speed up things

RUN echo -e "[global]\ntimeout = 60 \nindex-url = https://packagemanager.posit.co/pypi/latest/simple" > /etc/pip.conf 

RUN for PYTHON_VERSION in ${PYTHON_VERSION_LIST}; \
    do \
        /opt/python/${PYTHON_VERSION}/bin/pip install --upgrade \
            pip setuptools wheel && \
        scl enable gcc-toolset-14 "/opt/python/${PYTHON_VERSION}/bin/pip install \
            ipykernel \
            jupyter \
            rsconnect_jupyter \
            rsconnect_python \
            rsp_jupyter \
            jupyterlab~=4.2.4 \
            pwb_jupyterlab~=1.0 && \
            workbench_jupyterlab" && \
        /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension install --sys-prefix --py rsp_jupyter && \
        /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension enable --sys-prefix --py rsp_jupyter && \
        /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension install --sys-prefix --py rsconnect_jupyter && \
        /opt/python/${PYTHON_VERSION}/bin/jupyter-nbextension enable --sys-prefix --py rsconnect_jupyter && \
        /opt/python/${PYTHON_VERSION}/bin/jupyter-serverextension enable --sys-prefix --py rsconnect_jupyter && \
        /opt/python/${PYTHON_VERSION}/bin/python -m ipykernel install --name py${PYTHON_VERSION} --display-name "Python ${PYTHON_VERSION}" & \ 
    done; \
    wait
 
# Use default version to point to jupyter and python
ARG PYTHON_VERSION_DEFAULT
RUN if [ ! -z ${PYTHON_VERSION_DEFAULT} ]; then \
        ln -s /opt/python/${PYTHON_VERSION_DEFAULT}/bin/jupyter /usr/local/bin; \
        ln -s /opt/python/${PYTHON_VERSION_DEFAULT}/bin/python /usr/local/bin; \
        ln -s /opt/python/${PYTHON_VERSION_DEFAULT}/bin/python3 /usr/local/bin; \
    fi

# Install PWB session components 
ARG PWB_VERSION
RUN mkdir -p /usr/lib/rstudio-server && \
    yum install -y libcurl-devel openssl-devel rrdtool postgresql-libs ;\
    curl -O https://s3.amazonaws.com/rstudio-ide-build/session/rhel8/x86_64/rsp-session-rhel8-${PWB_VERSION}-x86_64.tar.gz ;\
    tar xfz rsp-session-rhel8-${PWB_VERSION}-x86_64.tar.gz -C /usr/lib/rstudio-server --strip=1 ;\
    rm -f rsp-session-rhel8-${PWB_VERSION}-x86_64.tar.gz

# Install Java JDK (optional) 
RUN yum -y install java-1.8.0-openjdk-devel 

ARG R_VERSION_LIST

# Install and configure new set of defined R versions
RUN for R_VERSION in ${R_VERSION_LIST}; \
do \
    yum install -y https://cdn.rstudio.com/r/centos-8/pkgs/R-${R_VERSION}-1-1.x86_64.rpm &&\

    # Set up gcc toolset 14 for R only (optional)
    echo -e "# GCC Toolset Root directory \n\
DEVTOOLSROOT=/opt/rh/gcc-toolset-14/root \n\
\n\
# Environment variables needed\n\
PCP_DIR=\${DEVTOOLSROOT} \n\
X_SCLS=gcc-toolset-14 \n\
SHLVL=4 \n\
DEBUGINFOD_URLS=https://debuginfod.centos.org/ \n\
\n\
MANPATH=\${DEVTOOLSROOT}/usr/share/man:\${MANPATH} \n\
PATH=/opt/rh/gcc-toolset-14/root/usr/bin:\${PATH} \n\
LD_LIBRARY_PATH=/opt/rh/gcc-toolset-14/root/usr/lib64:/opt/rh/gcc-toolset-14/root/usr/lib:\${LD_LIBRARY_PATH} \n\
PKG_CONFIG_PATH=/opt/rh/gcc-toolset-14/root/usr/lib64/pkgconfig:\${PKG_CONFIG_PATH} \n\
INFOPATH=/opt/rh/gcc-toolset-14/root/usr/share/info:\${INFOPATH}" > /opt/R/${R_VERSION}/lib/R/etc/Renviron.site && \
    # Update R Makevars to use the new compiler features from  
    # gcc toolset 14 (optional)
    R_HOME=/opt/R/${R_VERSION}/lib/R && \
    if [ -z ${R_HOME} ]; then echo "R_HOME not set"; exit 1; fi && \
    for std in 20 23 ;\
    do \
        sed -i "s/^CXX${std} .?*/CXX${std} = g++/ ; \
            s/^CXX${std}FLAGS .*/CXX${std}FLAGS = -g -O2 \$(LTO)/ ; \
            s/^CXX${std}PICFLAGS .*/CXX${std}PICFLAGS = -fpic/ ; \
            s/^CXX${std}STD .*/CXX${std}STD = -std=c++${std}/ " \
            $R_HOME/etc/Makeconf; \
    done &&\
    # Reconfigure R for Java (optional) 
    export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk && \
    /opt/R/${R_VERSION}/bin/R CMD javareconf && \
	echo $JAVA_HOME/lib/server > /etc/ld.so.conf.d/java.conf && \
    # Enable Java support for the RStudio IDE
    mkdir -p /etc/rstudio && \
    echo "Path: /opt/R/$rversion" >> /etc/rstudio/r-versions && \
    echo "Script: /opt/R/$rversion/lib/R/etc/ldpaths" >> /etc/rstudio/r-versions && \
    echo "" >> /etc/rstudio/r-versions && \
    # Need to make sure R is in PATH so that pak can run R as a subprocess
    rm -f /usr/local/bin/{R,Rscript} && \
    ln -s /opt/R/${R_VERSION}/bin/{R,Rscript} /usr/local/bin && \
    /opt/R/${R_VERSION}/bin/Rscript /run.R && \
    rm -f /usr/local/bin/{R,Rscript}; \
done && \
rm -f /run.R

# Defining system default version
ARG R_VERSION_DEFAULT
RUN if [ ! -z ${R_VERSION_DEFAULT} ]; then \
        ln -s /opt/R/${R_VERSION_DEFAULT}/bin/R /usr/local/bin && \
        ln -s /opt/R/${R_VERSION_DEFAULT}/bin/Rscript /usr/local/bin; \
    fi

# Installing frequently needed system dependencies 
# (Cf. https://docs.posit.co/connect/admin/r/dependencies/)
RUN dnf install -y epel-release
RUN dnf install -y cairo-devel openssl-devel make libcurl-devel mariadb-devel \
            unixODBC-devel java-1.8.0-openjdk-devel libxml2-devel git fontconfig-devel \
            freetype-devel libgit2-devel libssh2 zlib-devel glpk-devel libjpeg-turbo-devel \
            ImageMagick ImageMagick-c++ cmake libpng-devel libtiff-devel \
            mesa-libGLU-devel mesa-libGL-devel gdal-devel gdal sqlite-devel geos-devel proj-devel \
            libsodium-devel libicu-devel tcl tk tk-devel fribidi-devel harfbuzz-devel udunits2-devel

# SLURM integration (mandatory) 
RUN groupadd -g 401 slurm && \
    useradd -u 401 -g 401 slurm
    
RUN yum -y install munge-devel

# Install SLURM

# Note that the git branches on github do have a slightly different
# naming scheme - firstly the dots are replaced by dashes and
# secondly each SLURM version can have more than one release tag
# Here, we simply append "-1" to use the first git tag of a given
# SLURM version

RUN yum -y install git 
ARG SLURM_VERSION
RUN dir=`mktemp -d` && \
        cd $dir && \
        export SLURM_VER=${SLURM_VERSION} && git clone --depth 1 -b slurm-${SLURM_VER//./-}-1 https://github.com/SchedMD/slurm.git && \
        cd slurm && \
        ./configure --prefix /usr/local/slurm > /var/log/slurm-configure.log && \
        echo "Compiling SLURM" && \
        make -j 4 > /var/log/slurm-compile.log && \
        make install > /var/log/slurm-install.log && \
        echo "Installing SLURM" && \
        cd / && \
        rm -rf $dir && \
        ln -s /usr/local/slurm/bin/* /usr/local/bin


# Install zeromq as prereq for clustermq (optional) 
RUN yum -y install zeromq


# install apptainer 
ARG APPTAINER_VERSION
RUN dir=`mktemp -d` ;\
    cd $dir && \
    curl -L -O https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-${APPTAINER_VERSION}-1.x86_64.rpm && \
    curl -L -O https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-suid-${APPTAINER_VERSION}-1.x86_64.rpm && \
    yum install -y /usr/*bin/fuse2fs && \
    yum localinstall -y apptainer-${APPTAINER_VERSION}-1.x86_64.rpm && \
    yum localinstall -y apptainer-suid-${APPTAINER_VERSION}-1.x86_64.rpm && \
    rm -f apptainer* && \
    cd && \
    rm -rf $dir && \
    rm -rf /var/cache/yum/*

