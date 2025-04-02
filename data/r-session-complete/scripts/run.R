# Needs to be run as an admin that has write permissions to /etc/rstudio
# 
# This script when run against any R version will 
# * figure out which compatible BioConductor Version exist
# * get all the URLs for the repositories of BioConductor
# * Add both CRAN and BioConductor 
#       into files in /etc/rstudio/repos/repos-x.y.z.conf
# * add entries into /etc/rstudio/r-versions to define the respective 
#       R version (x.y.z) and point to the repos.conf file  
# * update Rprofile.site with the same repository informations 
# * add renv config into Renviron.site to use 
#       a global cache in $renvdir  
# * install 
#       * all needed R packages for Workbench to work 
#       * any additional packages listed in scripts/r-packages.txt 
#       and add them into the "site-library" of the respective R version  
# * create a pak pkg.lock file in "site-library"
#       for increased reproducibility
# * auto-detect which OS it is running on and add binary package support
# * uses a packagemanager running at $pmurl 
#       with repositories bioconductor and cran configured and named as such
# * assumes R binaries are installed into /opt/R/x.y.z

# main config parameters

# root folder for global renv cache 
renvdir<-"/scratch/renv"

# packagemanager URL to be used
pmurl <- "https://packagemanager.posit.co"

# place to create rstudio integration for package repos
rsconfigdir <- "/opt/rstudio/etc/rstudio" 

# increase timeout for packagemanager 
options(timeout = max(300, getOption("timeout")))

binaryflag<-""

if(file.exists("/etc/debian_version")) {
    binaryflag <- paste0("__linux__/",system(". /etc/os-release && echo $VERSION_CODENAME", intern = TRUE),"/")
}

if(file.exists("/etc/redhat-release")) {
    version <- strsplit(system(". /etc/os-release && echo $VERSION_ID", intern = TRUE),"[.]")[[1]][1]
    if (version == 9) { os <- "rhel" } else { os <- "centos" }
    binaryflag <- paste0("__linux__/",os,version,"/")
    Sys.setenv(PKG_SYSREQS_PLATFORM=paste0("redhat-",version))
    if (file.exists("/etc/rocky-release")) {
	Sys.setenv(PKG_SYSREQS_PLATFORM=paste0("rockylinux-",version))
	if (version == 8) {
	    Sys.setenv(PKG_SYSREQS_PLATFORM=paste0("centos-",version))
	}
    }
}

currver <- paste0(R.Version()$major,".",R.Version()$minor)

libdir <- paste0(R.home(),"/site-library")

if(dir.exists(libdir)) {unlink(libdir,recursive=TRUE)}
dir.create(libdir,recursive=TRUE)
.libPaths(libdir)

#directory for temporary packages
pkgtempdir<-tempdir()
.libPaths(pkgtempdir)

if (paste0(R.version$major,".",R.version$minor) < "4.4.0") {
#rjson released on Aug 20, 2024 needs R>=4.4.0, hence we need to make sure we install the older version
install_repo<-paste0(pmurl,"/cran/",binaryflag,"2024-08-15")
} else {
install_repo<-paste0(pmurl,"/cran/",binaryflag,"latest")
}
install.packages(c("rjson","RCurl","BiocManager"),pkgtempdir, repos=install_repo)

install.packages("pak", pkgtempdir, repos = sprintf(
  "https://r-lib.github.io/p/pak/%s/%s/%s/%s",
  "stable",
  .Platform $pkgType,
  R.Version()$os,
  R.Version()$arch
))

library(RCurl)
library(rjson)

jsondata<-fromJSON(file="https://raw.githubusercontent.com/rstudio/rstudio/main/src/cpp/session/resources/dependencies/r-packages.json")
pnames<-c()
for (feature in jsondata$features) { pnames<-unique(c(pnames,feature$packages)) }

currver <- paste0(R.Version()$major,".",R.Version()$minor)
paste("version",currver)

#Try to figure out if the needed Bioconductor release is older than the most recents
# If yes, use the release date of bioconduct version + 1 as a start date for looking 
# into CRAN snapshots - if no, use the current date
getbiocreleasedate <- function(biocvers){
  biocdata<-read.csv("/bioc.txt")
  
  splitbioc<-strsplit(as.character(biocvers),"[.]")[[1]]
  biocversnext<-paste0(splitbioc[1],".",as.integer(splitbioc[2])+1)
  
  repodate<-biocdata$Date[which(biocdata$X.Release==biocversnext)]
  if (identical(repodate,character(0))) repodate<-"latest"

  return(repodate)
}

#Start with a starting date for the time-based snapshot 60 days past the R release
releasedate <- as.Date(paste0(R.version$year,"-",R.version$month,"-",R.version$day))
paste("release", releasedate)
 
#Attempt to install packages from snapshot - if snapshot does not exist, decrease day by 1 and try again
getreleasedate <- function(repodate){
  
  repo=paste0(pmurl,"/cran/",binaryflag,repodate)
  paste(repo)
  URLfound=FALSE
  while(!URLfound) {
   if (!RCurl::url.exists(paste0(repo,"/src/contrib/PACKAGES"),useragent="curl/7.39.0 Rcurl/1.95.4.5")) {
	repodate<-as.Date(repodate)-1
        repo=paste0(pmurl,"/cran/",binaryflag,repodate)
   } else {
   URLfound=TRUE
   }
 }
 return(repodate)
}

# Version of BioConductor as given by BiocManager (can also be manually set)
biocvers <- BiocManager::version()

paste("Determining compatible CRAN snapshot")
biocreleasedate <- getbiocreleasedate(biocvers)
if (identical(biocreleasedate,"latest")) {
    releasedate <- "latest" 
} else {
  releasedate <- getreleasedate(biocreleasedate)
}

paste("snapshot selected", releasedate)

#Final CRAN snapsot URL
repo=paste0(pmurl,"/cran/",binaryflag,releasedate)
options(repos=c(CRAN=repo))

paste("CRAN Snapshot", repo)

paste("Configuring Bioconductor")
# Prepare for Bioconductor
options(BioC_mirror = paste0(pmurl,"/bioconductor"))
options(BIOCONDUCTOR_CONFIG_FILE = paste0(pmurl,"/bioconductor/config.yaml"))
sink(paste0("/opt/R/",currver,"/lib/R/etc/Rprofile.site"),append=FALSE)
options(BioC_mirror = paste0(pmurl,"/bioconductor"))
options(BIOCONDUCTOR_CONFIG_FILE = paste0(pmurl,"/bioconductor/config.yaml"))
sink()

# Make sure BiocManager is loaded - needed to determine BioConductor Version
library(BiocManager,quietly=TRUE,verbose=FALSE)

paste("Defining repos and setting them up in repos.conf as well as Rprofile.site")
# Bioconductor Repositories
r<-BiocManager::repositories(version=biocvers)

# enforce CRAN is set to our snapshot 
r["CRAN"]<-repo

# Make sure CRAN is listed as first repository (rsconnect deployments will start
# searching for packages in repos in the order they are listed in options()$repos
# until it finds the package
# With CRAN being the most frequenly use repo, having CRAN listed first saves 
# a lot of time
nr=length(r)
r<-c(r[nr],r[1:nr-1])

system(paste0("mkdir -p ",rsconfigdir,"/repos"))
filename=paste0(rsconfigdir,"/repos/repos-",currver,".conf")
sink(filename)
for (i in names(r)) {cat(noquote(paste0(i,"=",r[i],"\n"))) }
sink()

x<-unlist(strsplit(R.home(),"[/]"))
r_home<-paste0(x[2:length(x)-2],"/",collapse="")

sink(paste0(rsconfigdir,"/r-versions"), append=TRUE)
cat("\n")
cat(paste0("Path: ",r_home,"\n"))
cat(paste0("Label: R","\n"))
cat(paste0("Repo: ",filename,"\n"))
cat(paste0("Script: /opt/R/",currver,"/lib/R/etc/ldpaths \n"))
cat("\n")
sink()

sink(paste0("/opt/R/",currver,"/lib/R/etc/Rprofile.site"),append=FALSE)
if ( currver < "4.1.0" ) {
  cat('.env = new.env()\n')
}
cat('local({\n')
cat('r<-options()$repos\n')
for (line in names(r)) {
   cat(paste0('r["',line,'"]="',r[line],'"\n'))
}
cat('options(repos=r)\n') 

cat('if (nchar(Sys.getenv("TZ"))==0) Sys.setenv(TZ="Etc/UTC")\n')

options(BioC_mirror = paste0(pmurl,"/bioconductor"))
options(BIOCONDUCTOR_CONFIG_FILE = paste0(pmurl,"/bioconductor/config.yaml"))

if ( currver < "4.1.0" ) {
cat('}, envir = .env)\n')
cat('attach(.env)\n')
} else {
cat('})\n')
}
sink()




avpack<-available.packages(paste0(repo,"/src/contrib"))

#let's also add additional packages from a file called r-packages.txt  
Sys.setenv("CLUSTERMQ_USE_SYSTEM_LIBZMQ" = 0)

paste("Reading r-packages.txt")
packages_read=readLines("/r-packages.txt")
pnames=c(pnames,packages_read)

library(pak)

packages_needed<-pnames[pnames %in% avpack]

paste("Installing packages for RSW integration")
pak::pkg_install(packages_needed,lib=libdir)
paste("Creating lock file for further reproducibility")
pak::lockfile_create(packages_needed,lockfile=paste0(libdir,"/pkg.lock"))
pak::pak_cleanup(force=TRUE)

paste("Setting up global renv cache")
sink(paste0("/opt/R/",currver,"/lib/R/etc/Renviron.site"), append=TRUE)
  cat("RENV_PATHS_PREFIX_AUTO=TRUE\n")
  cat(paste0("RENV_PATHS_CACHE=", renvdir, "\n"))
  cat(paste0("RENV_PATHS_SANDBOX=", renvdir, "/sandbox\n"))
  cat(paste0('R_LIBS_USER=~/R/',R.Version()$platform,'/', 
    system('. /etc/os-release  && echo ${ID}',intern=TRUE),
    strsplit(system(". /etc/os-release && echo $VERSION_ID", intern = TRUE),"[.]")[[1]][1],
    '/', R.Version()$major,'.',strsplit(R.Version()$minor,'[.]')[[1]][1],"\n")
    )

sink()

paste("R_LIBS_USER_BASE_PATH magic")
sink(paste0("/opt/R/", currver, "/lib/R/etc/Rprofile.site"), append=TRUE)
# Add the lines to check and set the R_LIBS_USER environment variable
# to prepend R_LIBS_USER_BASE_PATH if the same is set
cat('# Redirect R_LIBS_USER if R_LIBS_USER_BASE_PATH is set\n')
cat('if (Sys.getenv("R_LIBS_USER_BASE_PATH") != "") {\n')
cat('  Sys.setenv(R_LIBS_USER = paste0(Sys.getenv("R_LIBS_USER_BASE_PATH"), substring(Sys.getenv("R_LIBS_USER"), 2)))\n')
cat('  if (!dir.exists(Sys.getenv("R_LIBS_USER"))) dir.create(Sys.getenv("R_LIBS_USER"),recursive=TRUE)\n')
cat('  .libPaths(c(unlist(strsplit(Sys.getenv("R_LIBS"), ":")), \n')
cat('              unlist(strsplit(Sys.getenv("R_LIBS_USER"), ":"))\n')
cat('             )\n')
cat('           )\n')
cat('}\n')
sink()

unlink(pkgtempdir)
