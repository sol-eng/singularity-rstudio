# Slurm Singularity SPANK Plugin

The Singularity SPANK plugin provides the users with an interface to launch an
application within a Linux container. The plug-in adds multiple command-line
options to the `salloc`, `srun` and `sbatch` commands. These options are then
propagated to a shell script [slurm-singularity-wrapper.sh][98] customizable by
the cluster administrator. This plugin is compatible to both Apptainer [^wtl3M]
and SinguarityCE [^oJ91o] (Sylabs Inc.) as container engine.

The Slurm SPANK plug-in mechanisms [^bk1WA] dynamically modifies the runtime behavior
of Slurm jobs:

> SPANK provides a very generic interface for stackable plug-ins which may be
> used to dynamically modify the job launch code in Slurm. SPANK plugins may be
> built without access to Slurm source code. They need only be compiled against
> Slurm's `spank.h` [^AV7Wy] header file, added to the SPANK config file
> `plugstack.conf`, and they will be loaded at runtime during the next job
> launch.

## Build

File                 | Description
---------------------|---------------------------------------------
[main.cpp](main.cpp) | Singularity SPANK plug-in source code

> All SPANK plug-ins should be recompiled when upgrading Slurm to a new major
> release. [^bk1WA]

Build this plug-in using `g++` from the GNU Compiler Collection (GCC) version 8
or newer. The plug-ins are compiled against this header file `spank.h` [02].
Fedora distributes this file in the `slurm-devel` RPM package [^DoUiD]. CMake is
available via the `cmake` package.

```sh
cmake -S . -B build # configure the project and choose a build dir
cmake --build build # build the Singularity SPANK plug-in
sudo cmake --install build # install the binary and configuration files
# on older CMake: cmake --build build --target install
```

By default the plug-in `singularity-exec.so` is installed to `/usr/lib64/slurm`.

Restart `slurmd` in order to load the plug-in after installation.

## Configuration

File                               | Description
-----------------------------------|---------------------------------------------
[singularity-exec.conf][99]        | Configuration file for the plug-in, add this to the `plugstack.conf.d` directory
[slurm-singularity-wrapper.sh][98] | Script executed by plug-in to launch a Singularity container

Basic configuration to enable the plug-in:

```bash
# configure the plug-in mechanism to load configurations from a sub-directory
mkdir /etc/slurm/plugstack.conf.d
cat > /etc/slurm/plugstack.conf <<EOF
include /etc/slurm/plugstack.conf.d/*.conf'
EOF
# reference the path to the plug-in and the wrapper script
cat > /etc/slurm/plugstack.conf.d/singularity-exec.conf <<EOF
required /usr/lib64/slurm/singularity-exec.so default= script=/usr/libexec/slurm-singularity-wrapper.sh bind= args=disabled
EOF
```

Note that the configuration illustrated above will be deployed by `make
install`. Modification to the plug-in configuration described below does not
required a restart of `slurmd`:

Option                 | Description
-----------------------|------------------------------------------------
`default=<path>`       | Path to the Singularity container launched by default. If this is set user require to explicitly use an empty `--singularity-container=` option to prevent the start of a container.
`script=<path>`        | Path to the wrapper script which consumes the input arguments and environment variables set by the plugin to launch the Singularity container.
`bind=<spec>`          | List of paths to bind-mount into the container by default. Please reference the section about [User-defined bind paths][95] in the Singularity User Documentation [^E9F6O].
`args=<string>`        | List of [command-line arguments][94] passed to `singularity exec`. Disable support for this feature by setting `args=disabled`. This will prompt an error for an unrecognized option if the user adds the `--singularity-args=` option. Use an empty string `args=""` to enable support for singularity arguments without a default configuration. Supply default for all users by adding a list of options i.e. `args="--home /network/$USER"`

Passing `-DINSTALL_PLUGSTACK_CONF=ON` to the CMake configure command will automate the above configuration.

## Usage

The plugin adds following command-line options to `salloc`, `srun` and `sbatch`:

Option                           | Description
---------------------------------|--------------------------------------
`--singularity-container=`       | Path to the Singularity container. Equivalent to using the environment variable `SLURM_SINGULARITY_CONTAINER`.
`--singularity-bind=`            | [User-defined bind paths][95] will be appended to the defaults specified in the plug-in configuration. Equivalent to using the environment variable `SLURM_SINGULARITY_BIND`.
`--singularity-args=`            | List of `singulairy exec` [command-line arguments][94].
`--singularity-no-bind-defaults` | Disable the bind mount defaults specified in the plug-in configuration.

The implementation of [slurm-singularity-wrapper.sh][98] adds additional environment variables:

Env. Variable                | Description
-----------------------------|-------------------------------------
`SLURM_SINGULARITY_DEBUG`    | Set `true` to enable debugging output
`SLURM_SINGULARITY_GLOBAL`   | Optional [global options][93] to the `singularity` command

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

## Development

Build the required singularity containers with the script [`containers.sh`][97].
(This requires the `singularity` command installed on the host). The containers
generated by the script are stored under `/tmp/*.sif`.

Start a test environment using the included [`Vagrantfile`][96]:

* Installs the `apptainer` package from Fedora EPEL
* Copies the SIF container images to `/tmp`
* Builds, installs and configures the Slurm Singularity plug-in

Start a Vagrant box to build an RPM package:

```sh
./containers.sh && vagrant up el8 && vagrant ssh el8 # for example...

# synced from the host
cd /vagrant

cmake -S . -B build # configure the project and choose a build dir
cmake --build build # build the Singularity SPANK plug-in
sudo cmake --install build # install the binary and configuration files

sudo systemctl enable --now munge slurmctld slurmd
```

## References

[^bk1WA]: SPANK - Slurm Plug-in Architecture
<https://slurm.schedmd.com/spank.html>

[^AV7Wy]: Slurm SPANK Header File
<https://github.com/SchedMD/slurm/blob/master/slurm/spank.h>

[^oJ91o]: SingularityCE, Sylabs Inc.
<https://sylabs.io>

[^wtl3M]: Apptainer, Linux Foundation
<https://apptainer.org>

[^E9F6O]: Apptainer Documentation
<https://apptainer.org/documentation>

[^DoUiD]: Fedora Slurm RPM Package
<https://src.fedoraproject.org/rpms/slurm>

[99]: singularity-exec.conf
[98]: slurm-singularity-wrapper.sh
[97]: containers.sh
[96]: Vagrantfile
[95]: https://singularity.hpcng.org/user-docs/master/bind_paths_and_mounts.html#user-defined-bind-paths
[94]: https://singularity.hpcng.org/user-docs/master/cli/singularity_exec.html
[93]: https://singularity.hpcng.org/user-docs/master/cli/singularity.html#options
