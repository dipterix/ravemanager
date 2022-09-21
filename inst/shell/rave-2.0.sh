#!/usr/bin/env Rscript

if(system.file(package="ravedash") == "") {
  if(system.file(package="ravemanager") == "") {
    utils::install.packages('ravemanager', repos = c(
      beauchamplab = 'https://beauchamplab.r-universe.dev',
      CRAN = 'https://cloud.r-project.org'))
  }
  ravemanager::install()
}


ravedash_port <- raveio::raveio_getopt("jupyter_port", default = 17284) - 1L
tryCatch({
  ravedash::start_session(host = "127.0.0.1", port = ravedash_port, as_job = FALSE,
                          launch_browser = TRUE, jupyter = FALSE)
}, error = function(e) {
  utils::browseURL(sprintf("http://127.0.0.1:%s", ravedash_port))
})



