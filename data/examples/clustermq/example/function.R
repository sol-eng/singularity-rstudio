renv::init()
renv::restore()
# Setting options for clustermq (can also be done in .Rprofile)
options(
    clustermq.scheduler = "slurm",
    clustermq.template = "slurm.tmpl" # if using your own template
)
  
# Loading libraries
library(clustermq)
library(foreach)
library(palmerpenguins)

# Register parallel backend to foreach
register_dopar_cmq(n_jobs=2, memory=1024, log_worker=TRUE, chunk_size=20000)

# Our dataset 
x<-penguins[which(penguins[,1] != "Adelie"),c(1,3)]

# Number of trials to simulate
trials <- 40000

# Main loop
res <- foreach(i=1:trials,.combine=rbind) %dopar% {
    ind <- sample(100, 100, replace=TRUE)
    result1 <- glm(x[ind,2]~x[ind,1], family=binomial(logit))
    coefficients(result1)
}

# Display results
res
