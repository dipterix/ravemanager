# DIPSAUS DEBUG START
# library(testthat)

remove_conda <- function() {
  try(silent = TRUE, {
    rpymat <- asNamespace("rpymat")
    root <- normalizePath(rpymat$install_root(), mustWork = FALSE)
    unlink(root, recursive = TRUE, force = TRUE)
  })
}

get_os <- function ()
{
  if ("windows" %in% tolower(.Platform$OS.type)) {
    return("windows")
  }
  os <- tolower(R.version$os)
  if (startsWith(os, "darwin")) {
    return("darwin")
  }
  if (startsWith(os, "linux")) {
    return("linux")
  }
  if (startsWith(os, "solaris")) {
    return("solaris")
  }
  if (startsWith(os, "win")) {
    return("windows")
  }
  return("unknown")
}

test_that("Installation works", {
  if(detect_gh_ci() && get_os() == "windows") {
    ravemanager::install()
    libpath <- .libPaths()[[1]]
    expect_true(nzchar(system.file(package = "ravebuiltins", lib.loc = libpath)))
    expect_true(nzchar(system.file(package = "rpyANTs", lib.loc = libpath)))
    rpyANTs <- asNamespace("rpyANTs")
    rpymat <- asNamespace("rpymat")

    on.exit({
      remove_conda()
    })

    # remove_conda()
    # ravemanager::configure_python()
    # expect_s3_class(rpyANTs$ants, c("ants.proxy", "python.builtin.module"))
  }
})
