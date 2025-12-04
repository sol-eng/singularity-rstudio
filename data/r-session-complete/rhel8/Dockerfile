FROM redhat/ubi8:latest

# Basic tools
COPY scripts/rhn.sh /
RUN bash /rhn.sh && rm /rhn.sh
RUN yum -y install yum-utils https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && yum-config-manager --enable codeready-builder-for-rhel-8-x86_64-rpms

# Install Pro Drivers
ARG PRO_DRIVERS_VERSION
COPY scripts/install-pro-driver.sh /
RUN /install-pro-driver.sh rpm ${PRO_DRIVERS_VERSION} && rm -f /install-pro-driver.sh
    
# Install TeXlive
RUN yum install perl -y
COPY scripts/install-texlive.sh /
RUN /install-texlive.sh && rm -f /install-texlive.sh
    
# Install Quarto
ARG QUARTO_VERSION
COPY scripts/install-quarto.sh /
RUN /install-quarto.sh ${QUARTO_VERSION} && rm -f /install-quarto.sh

# Install Python 
ARG PYTHON_VERSION_LIST
ARG PYTHON_VERSION_DEFAULT
COPY scripts/install-python.sh /
RUN /install-python.sh rpm centos-8 ${PYTHON_VERSION_DEFAULT} ${PYTHON_VERSION_LIST} && rm -f /install-python.sh deb

# Install PWB session components 
ARG PWB_VERSION
COPY scripts/install-session-components.sh /
RUN yum install -y libcurl-devel openssl-devel rrdtool postgresql-libs 
RUN /install-session-components.sh rhel8 ${PWB_VERSION} x86_64 && rm -f /install-session-components.sh
    
# Install Java JDK (optional) 
RUN yum -y install java-21-openjdk-devel

# Install GCC developer toolset
RUN yum -y install gcc-toolset-15

# Install and configure new set of defined R versions
ARG R_VERSION_LIST
COPY scripts/run.R /
COPY scripts/bioc.txt / 
COPY scripts/r-packages.txt /
RUN for R_VERSION in ${R_VERSION_LIST}; \
do \
    yum install -y https://cdn.rstudio.com/r/centos-8/pkgs/R-${R_VERSION}-1-1.x86_64.rpm &&\
    # Set up gcc toolset 15 for R only (optional)
    echo -e "# GCC Toolset Root directory \n\
DEVTOOLSROOT=/opt/rh/gcc-toolset-15/root \n\
\n\
# Environment variables needed\n\
PCP_DIR=\${DEVTOOLSROOT} \n\
X_SCLS=gcc-toolset-15 \n\
SHLVL=4 \n\
DEBUGINFOD_URLS=https://debuginfod.centos.org/ \n\
\n\
MANPATH=\${DEVTOOLSROOT}/usr/share/man:\${MANPATH} \n\
PATH=/opt/rh/gcc-toolset-15/root/usr/bin:\${PATH} \n\
LD_LIBRARY_PATH=/opt/rh/gcc-toolset-15/root/usr/lib64:/opt/rh/gcc-toolset-15/root/usr/lib:\${LD_LIBRARY_PATH} \n\
PKG_CONFIG_PATH=/opt/rh/gcc-toolset-15/root/usr/lib64/pkgconfig:\${PKG_CONFIG_PATH} \n\
INFOPATH=/opt/rh/gcc-toolset-15/root/usr/share/info:\${INFOPATH}" > /opt/R/${R_VERSION}/lib/R/etc/Renviron.site && \
    # Update R Makevars to use the new compiler features from  
    # gcc toolset 13 (optional)
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
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk && \
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
        ln -s /opt/R/${R_VERSION_DEFAULT}/bin/R /usr/local/bin && \
        ln -s /opt/R/${R_VERSION_DEFAULT}/bin/Rscript /usr/local/bin; \
    fi

# Install SLURM
ARG SLURM_VERSION 
COPY scripts/install-slurm.sh /
RUN yum install -y munge-devel
RUN /install-slurm.sh ${SLURM_VERSION} && rm -f /install-slurm.sh

#Install Apptainer
ARG APPTAINER_VERSION
COPY scripts/install-apptainer.sh /
RUN /install-apptainer.sh rpm ${APPTAINER_VERSION} && rm -f /install-apptainer.sh
