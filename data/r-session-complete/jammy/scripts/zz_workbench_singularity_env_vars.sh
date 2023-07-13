#!/bin/bash

SESSION_ID=`echo $RS_SESSION_URL | awk -F/ '{print $3}'`

if (which squeue >/dev/null) && [ ! -z $SESSION_ID ]; then 
  SLURM_ID=`squeue -o '%.7i %55j' | grep $SESSION_ID | awk '{print $1}'`
  env_file="/tmp/.slurm-$USER-$SLURM_ID.env"
  if [ ! -z $SLURM_ID && -f $env_file ]; then 
    source $env_file
  fi
fi
