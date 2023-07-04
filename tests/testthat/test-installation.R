# DIPSAUS DEBUG START
# library(testthat)
test_that("Installation works", {
  if(toupper(as.character(Sys.getenv("TEST_INSTALLATION"))) %in% c("TRUE", "YES")) {
    ravemanager::install()
    libpath <- .libPaths()[[1]]
    expect_true(nzchar(system.file(package = "ravebuiltins", lib.loc = libpath)))
    expect_true(nzchar(system.file(package = "rpyANTs", lib.loc = libpath)))
    rpyANTs <- asNamespace("rpyANTs")
    rpymat <- asNamespace("rpymat")

    on.exit({
      rpymat$remove_conda(ask = FALSE)
    })

    # rpymat$remove_conda(ask = FALSE)
    # ravemanager::configure_python()
    # expect_s3_class(rpyANTs$ants, c("ants.proxy", "python.builtin.module"))
  }
})
