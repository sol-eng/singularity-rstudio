# FAQ 

## How can I ensure that any session launched in Workbench will run in a container ? How can I prevent running Workbench without a container ?

You can set in `etc/plugstack.conf.d/singularity-exec.conf` in your SLURM installation directory a value for the default singularity container image by appending the container file name to the `default=` parameter in this line. 

Please note that this will make all SLURM jobs on the cluster use the default singularity container image (unless another image is specified). 
