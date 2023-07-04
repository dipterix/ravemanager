# DIPSAUS DEBUG START
# library(testthat)
test_that("Installation works", {
  if(as.character(Sys.getenv("TEST_INSTALLATION")) == "TRUE") {

    ravemanager::install()
    libpath <- .libPaths()[[1]]
    expect_true(nzchar(system.file(package = "ravebuiltins", lib.loc = libpath)))
    expect_true(requireNamespace(package = "raveio", lib.loc = libpath))

    ravemanager::configure_python()
    expect_true(requireNamespace(package = "rpyANTs", lib.loc = libpath))
    rpyANTs <- asNamespace("rpyANTs")
    expect_s3_class(rpyANTs$ants, c("ants.proxy", "python.builtin.module"))
  }
})
