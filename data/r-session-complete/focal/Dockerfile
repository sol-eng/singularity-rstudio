FROM ubuntu:focal 

# needed if you want to set up CRAN and BioConductor repos from RSPM (optional)
# set binaryflag to "" in order to stick to source RPMs
COPY scripts/run.R /
COPY scripts/bioc.txt / 

# Install Pro Drivers
ARG PRO_DRIVERS_VERSION
RUN apt-get update && apt-get install -y gdebi-core curl && \
    curl -O https://cdn.rstudio.com/drivers/7C152C12/installer/rstudio-drivers_${PRO_DRIVERS_VERSION}_amd64.deb && \
    gdebi -n rstudio-drivers_${PRO_DRIVERS_VERSION}_amd64.deb && \
    rm -f rstudio-drivers_${PRO_DRIVERS_VERSION}_amd64.deb

    
# Install TinyTeX 
RUN apt-get install -y curl wget perl-modules && \
    curl -sL "https://yihui.org/tinytex/install-bin-unix.sh" | sh \
        && /root/.TinyTeX/bin/*/tlmgr install \
            bookmark \
            caption \
            environ \
            fancyhdr \
            hardwrap \
            koma-script \
            morefloats \
            ms \
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
RUN for PYTHON_VERSION in ${PYTHON_VERSION_LIST}; \
    do \
        curl -O https://cdn.rstudio.com/python/ubuntu-2004/pkgs/python-${PYTHON_VERSION}_1_amd64.deb && \
        gdebi -n python-${PYTHON_VERSION}_1_amd64.deb && \
        rm -f python-${PYTHON_VERSION}_1_amd64.deb ; \
    done

# Configure Python versions to have 
#  - upgraded pip 
#  - configure pip to use posit package manager 
#  - preinstalling packages needed for the integration with other tools (e.g Connect) 
# Note: Install will run in parallel to speed up things
RUN bash -c echo -e "[global]\ntimeout = 60 \nindex-url = https://packagemanager.posit.co/pypi/latest/simple" > /etc/pip.conf 

RUN for PYTHON_VERSION in ${PYTHON_VERSION_LIST}; \
    do \
        /opt/python/${PYTHON_VERSION}/bin/pip install --upgrade \
            pip setuptools wheel && \
        /opt/python/${PYTHON_VERSION}/bin/pip install \
            ipykernel \
            jupyter \
            jupyterlab \
            rsconnect_jupyter \
            rsconnect_python \
            rsp_jupyter \
            workbench_jupyterlab && \
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
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl libcurl4-gnutls-dev libssl-dev libuser libuser1-dev rrdtool libpq5 && \
    curl -O https://s3.amazonaws.com/rstudio-ide-build/session/focal/amd64/rsp-session-focal-${PWB_VERSION}-amd64.tar.gz && \
    tar xfz rsp-session-focal-${PWB_VERSION}-amd64.tar.gz -C /usr/lib/rstudio-server --strip=1 && \
    rm -f rsp-session-focal-${PWB_VERSION}-amd64.tar.gz

# Install Java JDK (optional) 
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
	default-jdk 

# Install and configure new set of defined R versions
ARG R_VERSION_LIST
RUN for R_VERSION in ${R_VERSION_LIST}; \
    do \
        curl -O https://cdn.rstudio.com/r/ubuntu-2004/pkgs/r-${R_VERSION}_1_amd64.deb && \
        gdebi -n r-${R_VERSION}_1_amd64.deb && \
        rm -f r-${R_VERSION}_1_amd64.deb && \
        # Reconfigure R for Java (optional) 
        export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 && \
        /opt/R/${R_VERSION}/bin/R CMD javareconf && \
	    echo $JAVA_HOME/lib/server > /etc/ld.so.conf.d/java.conf && \
        # Need to make sure R is in PATH so that pak can run R as a subprocess
        PATH=/opt/R/${R_VERSION}/bin:$PATH /opt/R/${R_VERSION}/bin/Rscript /run.R; \
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
RUN apt install -y libcairo2-dev libssl-dev make libcurl4-openssl-dev \
            libmysqlclient-dev unixodbc-dev libnode-dev default-jdk libxml2-dev \
            git libfontconfig1-dev libfreetype6-dev libssh2-1-dev zlib1g-dev \
            libglpk-dev libjpeg-dev imagemagick libmagick++-dev gsfonts cmake \
            libpng-dev libtiff-dev python3 libglu1-mesa-dev libgl1-mesa-dev \
            libgdal-dev gdal-bin libgeos-dev libproj-dev libsqlite3-dev \
            libsodium-dev libicu-dev tcl tk tk-dev tk-table libfribidi-dev \
            libharfbuzz-dev libudunits2-dev

# Install zeromq as prereq for clustermq (optional) 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
        libzmq5 

# Install JAGS as prereq for rjags (optional)
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
        jags

# Install SLURM
RUN groupadd -g 401 slurm && \
    useradd -u 401 -g 401 slurm

RUN apt-get install -y libmunge-dev git

# Note that the git branches on github do have a slightly different
# naming scheme - firstly the dots are replaced by dashes and
# secondly each SLURM version can have more than one release tag
# Here, we simply append "-1" to use the first git tag of a given
# SLURM version

ARG SLURM_VERSION 
RUN dir=`mktemp -d` && \
        cd $dir && \
        rm -rf slurm && \
        export SLURM_VER=${SLURM_VERSION} && bash -c "git clone --depth 1 -b slurm-\${SLURM_VER//./-}-1 https://github.com/SchedMD/slurm.git" && \
        cd slurm && \
        ./configure --prefix /usr/local/slurm > /var/log/slurm-configure.log && \
        echo "Compiling SLURM" && \
        make -j 4 > /var/log/slurm-compile.log && \
        echo "Installing SLURM" && \
        make install > /var/log/slurm-install.log && \
        cd / && \
        rm -rf $dir && \
        ln -s /usr/local/slurm/bin/* /usr/local/bin

#Install Apptainer
ARG APPTAINER_VERSION

RUN dir=`mktemp -d` && \
    cd $dir  && \
    curl -L -O https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer_${APPTAINER_VERSION}_amd64.deb && \
    curl -L -O https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-suid_${APPTAINER_VERSION}_amd64.deb && \
    gdebi -n apptainer_${APPTAINER_VERSION}_amd64.deb && \
    gdebi -n apptainer-suid_${APPTAINER_VERSION}_amd64.deb && \
    rm -f apptainer* && \
    cd && \
    rm -rf $dir && \
    rm -rf /var/cache/yum/*
