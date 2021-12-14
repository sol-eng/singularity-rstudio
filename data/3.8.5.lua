help([==[

Description
===========
Apptainer/Singularity is the most widely used container system for HPC. It is de
signed to execute applications at bare-metal performance while being secure, por
table, and 100% reproducible. Apptainer is an open-source project with a friendl
y community of developers and users. The user base continues to expand, with App
tainer/Singularity now used across industry and academia in many areas of work.

More information
================
 - Homepage: https://apptainer.org/ 
]==])

whatis([==[Description: 
 Apptainer/Singularity is the most widely used container system for HPC. It is d
esigned to execute applications at bare-metal performance while being secure, po
rtable, and 100% reproducible. Apptainer is an open-source project with a friend
ly community of developers and users. The user base continues to expand, with Ap
ptainer/Singularity now used across industry and academia in many areas of work.
]==])
whatis([==[Homepage: https://apptainer.org]==])
whatis([==[URL: https://apptainer.org/]==])

local root = "/path/to/stack/singularity/3.8.5"


prepend_path("PATH", pathJoin(root, "bin"))
