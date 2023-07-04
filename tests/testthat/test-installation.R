# DIPSAUS DEBUG START
# library(testthat)

remove_conda <- function() {
  try(silent = TRUE, {
    rpymat <- asNamespace("rpymat")
    root <- normalizePath(rpymat$install_root(), mustWork = FALSE)
    unlink(root, recursive = TRUE, force = TRUE)
  })
}
test_that("Installation works", {
  if(toupper(as.character(Sys.getenv("TEST_INSTALLATION"))) %in% c("TRUE", "YES")) {
    ravemanager::install()
    libpath <- .libPaths()[[1]]
    expect_true(nzchar(system.file(package = "ravebuiltins", lib.loc = libpath)))
    expect_true(nzchar(system.file(package = "rpyANTs", lib.loc = libpath)))
    rpyANTs <- asNamespace("rpyANTs")
    rpymat <- asNamespace("rpymat")

    on.exit({
      remove_conda()
    })

    remove_conda()
    ravemanager::configure_python()
    expect_s3_class(rpyANTs$ants, c("ants.proxy", "python.builtin.module"))
  }
})
