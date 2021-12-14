[toc]

![](https://apptainer.org/user-docs/master/_static/logo.png)

# Introduction

[Singularity](https://apptainer.org/) is a tool very specific to HPC. It allows the execution of docker containers in user space. This alleviates the concern of granting admin privileges to end users on a shared file system. 

Singularity also comes with its own language to build a singularity container that is reasonably similar to what docker uses. 

Singularity can either run singularity containers or docker containers. The latter it transforms into singularity on-the-fly. 

The goal of this article is to 

* inform the installation and configuration of singularity on a HPC cluster running [SLURM](https://slurm.schedmd.com/) as a scheduler
* Configure [R Studio Workbench (RSW)](https://www.rstudio.com/products/workbench/) to use singularity containers on the same HPC

# High-level Overview of the steps 

1. Installation of Singularity
2. Setup a [SPANK](https://slurm.schedmd.com/spank.html) plugin for deep integration of singularity into SLURM
3. Build Singularity Containers for R Session and RSW based on the docker containers for [r-session-complete](https://hub.docker.com/r/rstudio/r-session-complete)
4. Configuration of RSW to use the singularity integration 
5. Simple tests for the new functionality
6. Hints and suggestions on how to use Singularity and R for increased reproducibility

# Assumptions/Requirements

* reasonably up-to-date vand fully functional version of SLURM (Version 19+)
* (optional) application stack using [environment modules ](https://modules.readthedocs.io/en/latest/) or [Lmod](https://lmod.readthedocs.io/en/latest/) with base directory in `appstack-path`
* persistent shared storage across the nodes (e.g. general NAS, NFS, GPFS, ...) to store the singularity images. Folder name will subsequently referred to as `container-path`
* transient shared storage across the nodes (e.g. Lustre, GPFS, ...) for scratch storage, subsequently referred to as `scratch-path`

# Installation of Singularity

For the installation simply follow along the [instructions](https://apptainer.org/admin-docs/master/installation.html#installation-on-linux). 

If you plan to integrate it into your application stack, make sure you choose a `prefix` that is compatible with your other applications in the stack and uses the same naming convention, e.g. `appstack-path/singularity/3.8.5` for Singularity 3.8.5. A [sample Lua Module](data/3.8.5.lua) is provided for conveniency.

# SPANK Plugin for Singularity
 
## Introduction

[SLURM](https://slurm.schedmd.com/) is a popular HPC scheduler that supports [SPANK](https://slurm.schedmd.com/spank.html) plugins. SPANK stands for **S**lurm **P**lug-in **A**rchitecture for **N**ode and job **K**ontrol. For the work considered here a new SPANK plugin is created that that will allow a deep integration of singularity into the HPC. 

While strictly not necessary, it will simplify the usage of singularity significantly for the end users. 

## Integration motivation & general idea

Instead of using a submit script for each singularity run like 

```
#!/bin/bash

ml load singularity/3.8.5
singularity run R-container.sif Rscript myCode.R
```

they can run straight

```
#!/path/to/Rscript 
#SBATCH --singularity-container my-R-container.sif

<R Code> 
```

i.e. add the SBATCH line above and other resource requirements to their R Code and submit this without the need of knowing all the details of the singularity implementation (`/path/to/Rscript` needs to resemble the path within the container.

## Setup and configuration of SPANK plugin

RStudio is not the first company that uses SPANK plugin for singularity integration. Many other Supercomputing Centers around the world have implemented such a plugin. 

We are therefore using an implementation from [GSI](https://git.gsi.de/SDE/slurm-singularity-exec/-/tree/master) that we extended further to make it even more flexible.  

Further details with up-to-date information can be found in [slurm-singularity-exec](slurm-singularity-exec.md
).

In order to install and configure the SPANK plugin for singularity specifically for our use case, please use the plugin from [github](https://github.com/rstudio/sol-eng-singularity/tree/main/slurm/slurm-singularity-exec). Before building and installing, please 

* replace in `singularity-exec-conf.tmpl`
   * `/efs/singularity/containers` by `container-path`
   * `/efs` by any storage path you want to have available within the container (if not necessary, please remove `/efs`)
   * `/scratch` by `scratch-path`
   * the remaining options should remain unchanged. The `path=` variables will create the bind mounts for the container: 
      * `/sys` for cgroups support 
      * `/var/run/munge`, `/etc/munge` and `/run/munge` for munge support 
      * `/var/spool/slurmd` to allow submitting jobs from within the container 
    

* replace in `slurm-singularity-wrapper.sh`
   * `/efs/singularity/3.8.5/bin/` with the full path to the singularity binary or the appropriate `ml`/`module` commands to load the module

Once done, simply run (with admin rights).

```
make install
```

Please note: Any of the above modifications can be done later on as well. 

Once the plugin is installed, please restart `slurmctld` via 

```
systemctl restart slurmctld
```
  
## Basic testing of new plugin

First let us build a singularity image from a docker container, e.g. from CentOS 8: 

```
singularity build centos8.img docker://centos:8
```

We now can run this command via singularity

```
singularity run centos8.img cat /etc/centos-release
```

which should show us that we are indeed running in CentOS 8.

To test the SPANK Plugin for singularity now we can run 

```
srun --pty --singularity-container-path=`pwd` --singularity-container centos8.img bash
Singularity> cat /etc/centos-release
```
If the above steps work, then the plugin is good to go for the next step. 

# Build Singularity Containers for R Session 

## General design principle

* reuse as much as possible, that is why we will use containers from [r-session-complete](https://hub.docker.com/r/rstudio/r-session-complete)
* only add as much as needed but also enough to make the use of the containers straightforward and seamless
* add some packages and configuration specific for HPC (e.g munge, zeromq as a pre-req for clustermq) 
* add renv to avoid the chicken-and-egg problem, i.e. to have renv installed in addition to all the other Base R packages
* configure renv to use a global package cache and add OS/linux-distro specific additional level in the directory structure
* add Java integration to the installed version of R since `rJava` is a problematic R package 
* setup binary repositories for CRAN and BioConductor from public RSPM
* for CentOS 7 add [devtoolset-10](https://access.redhat.com/documentation/en-us/red_hat_developer_toolset/10/html-single/user_guide/index) to allow for more recent compiler toolchain. 

## Singularity recipe

Appropriate singularity recipes can be found for [CentOS7](data/centos7) and [Ubuntu 2004](data/ubuntu2004). 

They can be built by running (using admin privileges)

```
singularity build r-session-complete.sif r-session-complete.sdef
```

Please note that this can be a very time-consuming process. Ensure that your temporary folder (e.g. `/tmp` or wherever the environment variable `TMP`/`TMPDIR` etc. points to) has sufficient amounts of disk space available. You will definitely need around 4 GB of disk space. A benefit of singularity containers is that they are much smaller (<50 % of docker image size) but they take a while to build.

# Configuration of RSW 

* Make sure the `launcher-sessions-callback-address` in `/etc/rstudio/rserver.conf` is set to an URL that is reachable from the compute nodes.
* Append to `/etc/rstudio/launcher.slurm.conf` the lines 

```
# Singularity specifics
constraints=Container=singularity-container
```

which will activate a new element in the web UI where users can specify the respectivee image they want to load. The slurm launcher will then appen the option `--singularity-container` with the value specified in this field to the sbatch command that will spawn the session. 

Thanks to setting up good defaults in the SPANK plugin (`--singularity-container-path|path`, `--singularity-bind|bind`) the user only needs to worry about the container name - even that is then being cached once typed in. 

