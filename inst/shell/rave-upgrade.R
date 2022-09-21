#!/usr/bin/env Rscript

utils::install.packages('ravemanager', repos = options(repos = c(
  beauchamplab = 'https://beauchamplab.r-universe.dev',
  CRAN = 'https://cloud.r-project.org')))
ravemanager::install()

