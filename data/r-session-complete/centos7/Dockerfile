FROM centos:7

# needed if you want to set up CRAN and BioConductor repos from RSPM (optional)
# set binaryflag to "" in order to stick to source RPMs
COPY scripts/run.R /
COPY scripts/bioc.txt / 

# Switch to vault for continued repo availability
RUN sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
RUN sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
RUN sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo

# Activate EPEL Release and powertools

RUN yum -y install yum-utils epel-release && yum-config-manager --enable powertools 

# Set up of developer toolset 11 to use a more recent version of the 
# compiler toolchain
RUN yum -y install centos-release-scl

# Switch to vault for continued repo availability
RUN sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
RUN sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
RUN sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo

RUN yum -y install devtoolset-11

# Install Pro Drivers

ARG PRO_DRIVERS_VERSION

RUN yum install -y \
        https://cdn.rstudio.com/drivers/7C152C12/installer/rstudio-drivers-${PRO_DRIVERS_VERSION}-1.el7.x86_64.rpm \
        && cp -f /opt/rstudio-drivers/odbcinst.ini.sample /etc/odbcinst.ini

# Install TinyTex

RUN yum install -y wget which perl-Digest-MD5
RUN curl -sL "https://yihui.org/tinytex/install-bin-unix.sh" | sh \
        && /root/.TinyTeX/bin/*/tlmgr install \
            bookmark \
            caption \
            environ \
            fancyhdr \
            hardwrap \
            koma-script \
            morefloats \
            oberdiek \
            pgf \
            setspace \
            tcolorbox \
            textcase \
            titlesec \
            tufte-latex \
            units \
            ulem \
            xcolor \
        && /root/.TinyTeX/bin/*/tlmgr path remove \
        && mv /root/.TinyTeX/ /opt/TinyTeX \
        && /opt/TinyTeX/bin/*/tlmgr option sys_bin /usr/local/bin \
        && /opt/TinyTeX/bin/*/tlmgr path add

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
        yum install -y https://cdn.rstudio.com/python/centos-7/pkgs/python-${PYTHON_VERSION}-1-1.x86_64.rpm ; \
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
        scl enable devtoolset-11 "/opt/python/${PYTHON_VERSION}/bin/pip install \
            ipykernel \
            jupyter \
            jupyterlab \
            rsconnect_jupyter \
            rsconnect_python \
            rsp_jupyter \
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
    curl -O https://s3.amazonaws.com/rstudio-ide-build/session/rhel7/x86_64/rsp-session-rhel7-${PWB_VERSION}-x86_64.tar.gz ;\
    tar xfz rsp-session-rhel7-${PWB_VERSION}-x86_64.tar.gz -C /usr/lib/rstudio-server --strip=1 ;\
    rm -f rsp-session-rhel7-${PWB_VERSION}-x86_64.tar.gz

# Install Java JDK (optional) 
RUN yum -y install java-1.8.0-openjdk-devel 

ARG R_VERSION_LIST

# Install and configure new set of defined R versions
RUN for R_VERSION in ${R_VERSION_LIST}; \
do \
    yum install -y https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm &&\
    # Set up gcc toolset 13 for R only (optional)
    echo -e "# GCC Toolset Root directory \n\
DEVTOOLSROOT=/opt/rh/devtoolset-11/root \n\
\n\
# Environment variables needed\n\
PATH=\${DEVTOOLSROOT}/usr/bin:\${PATH}\n\
LD_TMP=\${LD_LIBRARY_PATH}\n\
LD_LIBRARY_PATH=\${DEVTOOLSROOT}/usr/lib64\n\
LD_LIBRARY_PATH=\${DEVTOOLSROOT}/usr/lib:\${LD_LIBRARY_PATH}\n\
LD_LIBRARY_PATH=\${DEVTOOLSROOT}/usr/lib64/dyninst:\${LD_LIBRARY_PATH}\n\
LD_LIBRARY_PATH=\${DEVTOOLSROOT}/usr/lib/dyninst:\${LD_LIBRARY_PATH}\n\
LD_LIBRARY_PATH=\${DEVTOOLSROOT}/usr/lib64:\${LD_LIBRARY_PATH}\n\
LD_LIBRARY_PATH=\${DEVTOOLSROOT}/usr/lib:\${LD_LIBRARY_PATH}:\${LD_TMP}\n\
PKG_CONFIG_PATH=\${DEVTOOLSROOT}/usr/lib64/pkgconfig:\${PKG_CONFIG_PATH}\n\
INFOPATH=\${DEVTOOLSROOT}/usr/share/info:\${INFOPATH}\n\
MANPATH=\${DEVTOOLSROOT}/usr/share/man:\${MANPATH}\n\
\n\
X_SCLS=devtoolset-11\n\
PCP_DIR=\${DEVTOOLSROOT}" > /opt/R/${R_VERSION}/lib/R/etc/Renviron.site && \
    # Update R Makevars to use the new compiler features from  
    # devtoolset-11 (optional)
    R_HOME=/opt/R/${R_VERSION}/lib/R && \
    if [ -z ${R_HOME} ]; then echo "R_HOME not set"; exit 1; fi && \
    for std in 14 17 20 ;\
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
        ln -s /opt/R/${R_VERSION_DEFAULT}/bin/R /usr/local/bin; \
        ln -s /opt/R/${R_VERSION_DEFAULT}/bin/Rscript /usr/local/bin; \
    fi

# Installing frequently needed system dependencies 
# (Cf. https://docs.posit.co/connect/admin/r/dependencies/)
RUN yum install -y epel-release
RUN yum install -y cairo-devel openssl-devel make libcurl-devel mariadb-devel \
    unixODBC-devel v8-devel java-1.8.0-openjdk-devel libxml2-devel git \
    fontconfig-devel freetype-devel libgit2-devel libssh2-devel zlib-devel \
    glpk-devel libjpeg-turbo-devel ImageMagick ImageMagick-c++-devel \
    cmake cmake3 libpng-devel libtiff-devel mesa-libGLU-devel mesa-libGL-devel \
    gdal-devel gdal geos-devel proj-devel proj-epsg sqlite-devel libsodium-devel \
    libicu-devel tcl tk tk-devel fribidi-devel harfbuzz-devel udunits2-devel

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

# Install JAGS 4.3.0 as requiremnt for rjags
RUN dir=`mktemp -d` && \
    cd $dir && \
    curl -O -L  https://sourceforge.net/projects/mcmc-jags/files/JAGS/4.x/Source/JAGS-4.3.2.tar.gz/download && \
    tar xvfz download && \
    cd JAGS-4.3.2  && \
    ./configure --with-blas="-lopenblas" && make && make install  && \
    cd  && \
    rm -rf $dir 
