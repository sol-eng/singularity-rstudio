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
        local path="$SLURM_SINGULARITY_CONTAINER_PATH"
        _debug "SLURM_SINGULARITY_CONTAINER_PATH=$path"

	if [ -z $path ]; then
		test -f $container || _error "$container missing"
		_debug "SLURM_SINGULARITY_CONTAINER=$container"
	else
	        test -f $path/$container || _error "$container missing in $path"
		_debug "SLURM_SINGULARITY_CONTAINER=$path/$container"
	fi	

	local args="$SLURM_SINGULARITY_ARGS"
        _debug "SLURM_SINGULARITY_ARGS=$args"

	local bind="$SLURM_SINGULARITY_BIND"
        _debug "SLURM_SINGULARITY_BIND=$bind"

	local global="$SLURM_SINGULARITY_GLOBAL"
        _debug "SLURM_SINGULARITY_GLOBAL=$global"

        local instance_name="singularity-`cat /proc/sys/kernel/random/uuid | sed 's/[-]//g'`"
        _debug "instance_name=$instance_name"

        local command="/usr/bin/singularity instance start $global --bind=$bind $args $container $instance_name && /usr/bin/singularity shell instance://$instance_name $@ && /usr/bin/singularity instance stop $instance_name"
        _debug "$command"

        echo "Start Singularity container $container"
        bash -c  "$command"
}

run_in "$@"
