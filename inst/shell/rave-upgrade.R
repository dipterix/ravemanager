#!/usr/bin/env Rscript

utils::install.packages("ravemanager", repos = options(repos = c(
  "rave-ieeg" = "https://rave-ieeg.r-universe.dev",
  "CRAN" = "https://cloud.r-project.org")))
ravemanager::install()

