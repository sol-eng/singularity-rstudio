FROM ubuntu:focal 

# Basic tools
RUN apt-get update && apt-get install -y gdebi-core curl wget

# Install Pro Drivers
ARG PRO_DRIVERS_VERSION
COPY scripts/install-pro-driver.sh /
RUN /install-pro-driver.sh deb ${PRO_DRIVERS_VERSION} && rm -f /install-pro-driver.sh
    
# Install TeXlive
RUN apt-get install libpod-simple-perl -y
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
RUN /install-python.sh deb  ubuntu-2004 ${PYTHON_VERSION_DEFAULT} ${PYTHON_VERSION_LIST} && rm -f /install-python.sh deb

# Install PWB session components 
ARG PWB_VERSION
COPY scripts/install-session-components.sh /
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y curl libcurl4-gnutls-dev libssl-dev libuser libuser1-dev rrdtool libpq5
RUN /install-session-components.sh focal ${PWB_VERSION} && rm -f /install-session-components.sh
    
# Install Java JDK (optional) 
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
	default-jdk 

# Install and configure new set of defined R versions
ARG R_VERSION_LIST
COPY scripts/run.R /
COPY scripts/bioc.txt / 
COPY scripts/r-packages.txt /
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

# Install SLURM
ARG SLURM_VERSION 
COPY scripts/install-slurm.sh /
RUN apt-get install -y libmunge-dev git
RUN /install-slurm.sh ${SLURM_VERSION} && rm -f /install-slurm.sh

#Install Apptainer
ARG APPTAINER_VERSION
COPY scripts/install-apptainer.sh /
RUN /install-apptainer.sh deb ${APPTAINER_VERSION} && rm -f /install-apptainer.sh
