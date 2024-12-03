#!/bin/sh

VERSION=1.0

_debug() {
        if [ "$SLURM_SINGULARITY_DEBUG" = "true" ]; then
                echo 1>&2 "Debug: $@"
        fi
}

_error() {
        echo 1>&2 "Error: $@"
	exit 1
}

run_in() {

	local container="$1"
	shift
        test -f $container || _error "$container missing"
        _debug "SLURM_SINGULARITY_CONTAINER=$container"

	local args="$SLURM_SINGULARITY_ARGS"
        _debug "SLURM_SINGULARITY_ARGS=$args"

	local bind="$SLURM_SINGULARITY_BIND"
        _debug "SLURM_SINGULARITY_BIND=$bind"

	local global="$SLURM_SINGULARITY_GLOBAL"
        _debug "SLURM_SINGULARITY_GLOBAL=$global"

        local command="singularity $global exec --bind=$bind $args $container $@"
        _debug "$command"

        # export the PATH and LD_LIBRARY_PATH environment variable to the container
        #export SINGULARITYENV_PATH=$PATH
        #export SINGULARITYENV_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
        export APPTAINERENV_PATH=$PATH
        export APPTAINERENV_LD_LIBRARY_PATH=$LD_LIBRARY_PATH

        echo "Start container image $container"
        exec $command
}

run_in "$@"
