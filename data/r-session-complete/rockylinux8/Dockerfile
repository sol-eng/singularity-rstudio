FROM rockylinux:8

# Basic tools
RUN yum -y install yum-utils libxml2-devel epel-release && crb enable

# Install modern gdal/proj/geos from PostgreSQL community repo (pgdg-common).
# The RHEL/Rocky base gdal is too old for current terra/sf; pgdg-common ships
# versioned side-by-side installs under /usr/gdalNN /usr/projNN /usr/geosNN.
# The corresponding bin/lib/pkgconfig dirs are wired into each R installation's
# Renviron.site below rather than into /etc/ld.so.conf.d, to keep the
# modification scoped to R.
RUN yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    yum -y --enablerepo=pgdg-common install \
        gdal38-devel proj96-devel geos313-devel && \
    ln -sf /usr/gdal38/bin/gdal-config /usr/local/bin/gdal-config && \
    ln -sf /usr/geos313/bin/geos-config /usr/local/bin/geos-config

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
PATH=/usr/gdal38/bin:/usr/proj96/bin:/usr/geos313/bin:/opt/rh/gcc-toolset-15/root/usr/bin:\${PATH} \n\
LD_LIBRARY_PATH=/usr/gdal38/lib:/usr/gdal38/lib64:/usr/proj96/lib:/usr/proj96/lib64:/usr/geos313/lib:/usr/geos313/lib64:/opt/rh/gcc-toolset-15/root/usr/lib64:/opt/rh/gcc-toolset-15/root/usr/lib:\${LD_LIBRARY_PATH} \n\
PKG_CONFIG_PATH=/usr/gdal38/lib/pkgconfig:/usr/gdal38/lib64/pkgconfig:/usr/proj96/lib/pkgconfig:/usr/proj96/lib64/pkgconfig:/usr/geos313/lib/pkgconfig:/usr/geos313/lib64/pkgconfig:/opt/rh/gcc-toolset-15/root/usr/lib64/pkgconfig:\${PKG_CONFIG_PATH} \n\
CPPFLAGS=-I/usr/gdal38/include -I/usr/proj96/include -I/usr/geos313/include \n\
LDFLAGS=-L/usr/gdal38/lib -L/usr/gdal38/lib64 -L/usr/proj96/lib -L/usr/proj96/lib64 -L/usr/geos313/lib -L/usr/geos313/lib64 \n\
CXXFLAGS=-g -O2 -fpermissive -Wno-error=template-body -Wno-template-body \n\
CFLAGS=-g -O2 \n\
INFOPATH=/opt/rh/gcc-toolset-15/root/usr/share/info:\${INFOPATH}" > /opt/R/${R_VERSION}/lib/R/etc/Renviron.site && \
    # Update R Makevars to use the new compiler features from  
    # gcc toolset 13 (optional)
    R_HOME=/opt/R/${R_VERSION}/lib/R && \
    if [ -z ${R_HOME} ]; then echo "R_HOME not set"; exit 1; fi && \
    sed -i "s/^CXX = .*/CXX = g++/ ; \
        s/^CXXFLAGS = .*/CXXFLAGS = -g -O2 -fpermissive -Wno-error=template-body -Wno-template-body \$(LTO)/ ; \
        s/^CXXPICFLAGS = .*/CXXPICFLAGS = -fpic/" \
        $R_HOME/etc/Makeconf && \
    for std in 17 20 23 ;\
    do \
        sed -i "s/^CXX${std} .*/CXX${std} = g++/ ; \
            s/^CXX${std}FLAGS .*/CXX${std}FLAGS = -g -O2 -fpermissive -Wno-error=template-body -Wno-template-body \$(LTO)/ ; \
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
RUN yum install -y munge-devel git
RUN /install-slurm.sh ${SLURM_VERSION} && rm -f /install-slurm.sh

