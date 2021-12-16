renv::init()
renv::restore()
library(batchtools)

# Create Registry
reg = makeRegistry(file.dir = paste0(getwd(),"/registry"), seed = 1)
#reg = makeRegistry(file.dir = NA, seed = 1)

# define function
glmfunction <- function(n) {
  ind <- sample(100, 100, replace=TRUE)
  result1 <- glm(x[ind,2]~x[ind,1], family=binomial(logit))
  coefficients(result1)
}

trials <- 40000

library(palmerpenguins)

# Our dataset
x<-penguins[which(penguins[,1] != "Adelie"),c(1,3)]

# Mapping input parameters to function
ids<-batchMap(fun=glmfunction, n=1:trials)

# Chunk jobs for better performance
#ids[, chunk := chunk(job.id, chunk.size = 2000)]
ids[, chunk := chunk(job.id, n.chunks = 20)]

# Exporting data (x) to slaves
batchExport(export = list(x = x), reg = reg)

# Submit jobs to queue 
submitJobs(ids=ids,resources = list(walltime = 360, memory = 1024))

# Waiting for all jobs done
waitForJobs()

# Reduce the results into a final dataset
res<-reduceResults(rbind, init = data.frame(), reg = reg)

# Display result res
colnames(res) <- c("(Intercept)","x[ind, 1]")
res
