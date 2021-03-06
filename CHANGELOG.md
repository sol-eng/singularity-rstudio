# Change Log
All notable changes to this project will be documented in this file.
 
The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).
 
## [0.1] - 2021-12-15
  
### Added

First version of the Singularity/RStudio Workbench integration 
					using the SLURM launcher
 
### Changed
  
### Fixed
 
## [0.2] - 2021-12-20 
 
### Added

- Integrating SLURM installation into docker container for Workbench 
  as well into Singularity container for r-session-complete
- Deferring [configless SLURM](https://slurm.schedmd.com/configless_slurm.html) to a later time.
   
### Changed
 
### Fixed

- Preventing possible issues when bind-mounting SLURM installation from the submit node into the RSW docker images (e.g. software dependencies, incompatible linux distributions, ...) by building SLURM from sources during container build time   
