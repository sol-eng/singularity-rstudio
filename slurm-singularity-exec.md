This is a fork with modifications/additions from https://git.gsi.de/SDE/slurm-singularity-exec.git

# Slurm Singularity SPANK Plug-in

The Slurm SPANK plug-in mechanisms dynamically modifies the runtime behavior
of Slurm jobs:

> SPANK provides a very generic interface for stackable plug-ins which may be
> used to dynamically modify the job launch code in Slurm. SPANK plugins may be
> built without access to Slurm source code. They need only be compiled against
> Slurm's [`spank.h`](https://github.com/SchedMD/slurm/blob/master/slurm/spank.h)  header file, added to the SPANK config file
> `plugstack.conf`, and they will be loaded at runtime during the next job
> launch.

The Singularity SPANK plug-in provides the users with an interface to launch an
application within a Singularity container. The plug-in adds multiple
command-line options to the `salloc`, `srun` and `sbatch` commands. These
options are then propagated to a shell script
`slurm-singularity-wrapper.sh` that is customizable by the cluster administrator.

## Build

File                 | Description
---------------------|---------------------------------------------
`main.cpp` | Singularity SPANK plug-in
`spank.h`   | SPANK plug-ins are compiled against this header file 

> All SPANK plug-ins should be recompiled when upgrading Slurm to a new major
> release.

Build this plug-in using `g++` from the GNU Compiler Collection (GCC) version 8
or newer:

```sh
# build the Singularity SPANK plug-in
make singularity-exec.so
# build the plug-in, and install the binary and configuration files
make install
```

By default 

* the base directory of the slurm installation is `/opt/slurm` (defined via `slurmdir`) 
* the SLURM configuration files (e.g. `slurm.conf`) are installed in `/opt/slurm/etc` (defined via `etcdir`) 
* the plug-in `singularity-exec.so` is installed to `/opt/slurm/etc/spank` (defined via `libdir`). 
* singularity will bind-mount the SLURM installation in /opt/slurm (defined via `slurmdir`) 
* add /opt/slurm/bin to the PATH environment variable within the container 

If you need to change anything, append `slurmdir`, `libdir=...` and `etcdir=...` to the make install command.

Restart `slurmctld` in order to load the plug-in after installation.

## Configuration

File                               | Description
-----------------------------------|---------------------------------------------
singularity-exec.conf       | Configuration file for the plug-in, add this to the `plugstack.conf.d` directory
slurm-singularity-wrapper.sh | Script executed by plug-in to launch a Singularity container

Basic configuration to enable the plug-in:

```bash
# configure the plug-in mechanism to load configurations from a sub-directory
mkdir /etc/slurm/plugstack.conf.d
cat > /etc/slurm/plugstack.conf <<EOF
include /etc/slurm/plugstack.conf.d/*.conf'
EOF
# reference the path to the plug-in and the wrapper script 
cat > /etc/slurm/plugstack.conf.d/singularity-exec.conf <<EOF
required /etc/slurm/spank/singularity-exec.so default= script=/etc/slurm/spank/slurm-singularity-wrapper.sh bind= args=disabled
EOF
```

Note that the configuration illustrated above will be deployed by `make
install`.

Modification to the plug-in configuration described below does not required a
restart of `slurmctld`:

Option                 | Description
-----------------------|------------------------------------------------
`default=<path>`       | Path to the Singularity container launched by default. If this is set user require to explicitly use an empty `--singularity-container=` option to prevent the start of a container.
`script=<path>`        | Path to the wrapper script which consumes the input arguments and environment variables set by the plugin to launch the Singularity container. 
`bind=<spec>`          | List of paths to bind-mount into the container by default. Please reference the section about [User-defined bind paths][95] in the Singularity User Documentation [04].
`path=<path>`	          | Directory where singularity containers are stored. If set, `--singularity-container` (see below) does not need the fully qualified path but just the file name. 
`args=<string>`        | List of [command-line arguments][94] passed to `singularity exec`. Disable support for this feature by setting `args=disabled`. This will prompt an error for an unrecognized option if the user adds the `--singularity-args=` option. Use an empty string `args=""` to enable support for singularity arguments without a default configuration. Supply default for all users by adding a list of options i.e. `args="--home /network/$USER"`

## Usage

The plugin adds following command-line options to `salloc`, `srun` and `sbatch`:

Option                           | Description
---------------------------------|--------------------------------------
`--singularity-container=`       | Path to the Singularity container. Equivalent to using the environment variable `SLURM_SINGULARITY_CONTAINER`.
`--singularity-bind=`            | [User-defined bind paths][95] will be appended to the defaults specified in the plug-in configuration. Equivalent to using the environment variable `SLURM_SINGULARITY_BIND`.
`--singularity-container-path`.  | Common path where singularity containers are stored. Equivalent to using the environment variable `SLURM_SINGULARITY_CONTAINER_PATH`
`--singularity-args=`            | List of `singularity exec` [command-line arguments][94].
`--singularity-no-bind-defaults` | Disable the bind mount defaults specified in the plug-in configuration.

The implementation of `slurm-singularity-wrapper.sh` adds additional environment variables:

Env. Variable                | Description
-----------------------------|-------------------------------------
`SLURM_SINGULARITY_DEBUG`    | Set `true` to enable debugging output
`SLURM_SINGULARITY_GLOBAL`   | Optional global options to the `singularity` command

Following `srun` command use the options and environment variables described above:

```bash
SLURM_SINGULARITY_DEBUG=true SLURM_SINGULARITY_GLOBAL=--silent \
      srun --singularity-container=/tmp/debian10.sif \
           --singularity-bind=/srv \
           --singularity-args="--no-home" \
           -- /bin/grep -i pretty /etc/os-release
```

Executing it will generate output similar to:

```
Start Singularity container /tmp/debian10.sif
Debug: SLURM_SINGULARITY_CONTAINER=/tmp/debian10.sif
Debug: SLURM_SINGULARITY_ARGS=--no-home
Debug: SLURM_SINGULARITY_BIND=/etc/slurm,/var/run/munge,/var/spool/slurm
Debug: SLURM_SINGULARITY_GLOBAL=--silent
Debug: singularity --silent exec --bind=/etc/slurm,/var/run/munge,/var/spool/slurm,/srv --no-home /tmp/debian10.sif /bin/grep -i pretty /etc/os-release
PRETTY_NAME="Debian GNU/Linux 10 (buster)"
```

Similar use with the `sbatch` command:

```bash
cat > job.sh <<EOF
#!/usr/bin/env bash
#SBATCH --singularity-container /tmp/debian10.sif
#SBATCH --singularity-bind=/srv
#SBATCH --singularity-args="--no-home"
/bin/grep -i pretty /etc/os-release
EOF
SLURM_SINGULARITY_DEBUG=true SLURM_SINGULARITY_GLOBAL=--silent sbatch job.sh 
```



