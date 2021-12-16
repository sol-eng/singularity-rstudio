# Singularity 

This folder contains various singularity recipes. 

Examples on how to use [batchtools](batchtools) and [clustermq](clustermq) are stored in the subfolders.

You can build the singularity images via

```bash
singularity build R-4.0.5.bionic.sif R.bionic.sdef
singularity build R-4.0.5.centos7.sif R.centos7.sdef 
```

If you would like to build for other versions of R, simply change the `R_VERSION` variable in the `sdef` file. 

Make sure you copy the container images into the folder that is the default value for `--singularity-container-path`. Otherwise you will need to add this option to the respective template files.  
