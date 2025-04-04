#!/bin/bash

export SLURM_CONF=/opt/slurm/etc/slurm.conf

SESSION_ID=`echo $RS_SESSION_URL | awk -F/ '{print $3}'`

if (which squeue >/dev/null) && [ ! -z $SESSION_ID ]; then
  # R session has started, user launches a Terminal 
  SLURM_ID=`squeue -o '%.7i %55j' | grep $SESSION_ID | awk '{print $1}'`
else
  # SESSION_ID could not be determined, e.g. R session only starting up
  SLURM_ID=`ls -tra /tmp/.slurm-$USER-*.env  | tail -1 | cut -d "-" -f 3 | sed 's/.env//'`
fi

if [ ! -z $SLURM_ID ]; then
  env_file="/tmp/.slurm-$USER-$SLURM_ID.env"
  if [ -n "$SLURM_ID" ]  && [ -f $env_file ]; then
    source $env_file
  fi
fi

